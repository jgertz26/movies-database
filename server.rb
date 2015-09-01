require "sinatra"
require "pg"
require "shotgun"
require "pry"

use Rack::Session::Cookie, {
  secret: "keep_it",
  expire_after: 100
}

def db_connection
  begin
    connection = PG.connect(dbname: "movies")
    yield(connection)
  ensure
    connection.close
  end
end

def flip(direction)
  if direction == "ASC"
    "DESC"
  else
    "ASC"
  end
end

get '/' do
  redirect '/movies'
end

get '/actors' do
  page = params["page"].to_i
  if page == 0
    page = 1
    start = 0
  else
    start = (page.to_i - 1) * 100
  end

  total_actors = db_connection { |conn| conn.exec("SELECT count(*) FROM actors")[0]['count'].to_i }
  last_page = (total_actors / 100) + 1
  sql = "SELECT name FROM actors ORDER BY name OFFSET #{start} ROWS FETCH NEXT 100 ROWS ONLY"
  actors = db_connection { |conn| conn.exec(sql).to_a }
  erb :'actors/index', locals: {actors: actors, page: page, last_page: last_page}
end

get '/actors/:id' do
  actor = params["id"]
  actor_id = db_connection { |conn| conn.exec("SELECT id FROM actors WHERE name='#{actor}'")[0]['id'] }
  sql = "SELECT movies.id, movies.title, cast_members.character, movies.year
         FROM movies
         JOIN cast_members
         ON movies.id = cast_members.movie_id
         WHERE cast_members.actor_id='#{actor_id}'
         ORDER BY movies.year DESC"
  roles = db_connection { |conn| conn.exec(sql).to_a }
  erb :'actors/show', locals: {roles: roles, actor: actor}
end

get '/movies' do
  page = params["page"].to_i
  if page == 0
    page = 1
    start = 0
  else
    start = (page.to_i - 1) * 100
  end

  total_movies = db_connection { |conn| conn.exec("SELECT count(*) FROM movies")[0]['count'].to_i }
  last_page = (total_movies / 100) + 1

  order_by = params["order"]
  search = session[:search]
  if order_by.nil?
    order_by = "movies.title"
    session[:direction] = "ASC"
  elsif order_by == session[:sort_item]
    session[:direction] = flip(session[:direction])
  end

  sql = "SELECT movies.id, movies.title, movies.year,
         movies.rating, genres.name AS genre, studios.name AS studio
         FROM movies
         JOIN genres
         ON movies.genre_id = genres.id
         JOIN studios
         ON movies.studio_id = studios.id"
  if search.nil?
    sql.concat(" ORDER BY #{order_by} #{session[:direction]}")
  else
    sql.concat(" WHERE movies.title ILIKE '%#{search}%' ORDER BY movies.title ")
  end

  movies = db_connection { |conn| conn.exec(sql).to_a }
  session[:sort_item] = order_by
  session[:search] = nil
  erb :'movies/index', locals: {movies: movies, search: search, page: page, last_page: last_page}
end

get '/movies/:id' do

  movie_id = params["id"]
  sql = "SELECT movies.title, movies.year, genres.name AS genre, studios.name AS studio
         FROM movies
         JOIN genres
         ON movies.genre_id = genres.id
         JOIN studios
         ON movies.studio_id = studios.id
         WHERE movies.id='#{movie_id}'"
   movie_info = db_connection { |conn| conn.exec(sql)[0] }
   sql = "SELECT cast_members.character, actors.name AS actor
          FROM cast_members
          JOIN actors
          ON cast_members.actor_id = actors.id
          JOIN movies
          ON cast_members.movie_id = movies.id
          WHERE movies.id='#{movie_id}'"
   cast = db_connection { |conn| conn.exec(sql).to_a }
  erb :'movies/show', locals: {movie: movie_info, cast: cast}
end

post '/movies' do
  session[:search] = params["search"]
  redirect "/movies"
end
