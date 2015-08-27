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
  binding.pry
  if page == 0
    page = 1
    start = 0
  else
    start = (page.to_i - 1) * 100
  end

  sql = "SELECT name FROM actors ORDER BY name OFFSET #{start} ROWS FETCH NEXT 100 ROWS ONLY"
  actors = db_connection { |conn| conn.exec(sql).to_a }
  erb :'actors/index', locals: {actors: actors, page: page}
end

get '/actors/:id' do
  actor = params["id"]
  actor_id = db_connection { |conn| conn.exec("SELECT id FROM actors WHERE name='#{actor}'")[0]['id'] }
  sql = "SELECT movies.title, cast_members.character, movies.year
         FROM movies
         JOIN cast_members
         ON movies.id = cast_members.movie_id
         WHERE cast_members.actor_id='#{actor_id}'
         ORDER BY movies.year DESC"
  roles = db_connection { |conn| conn.exec(sql).to_a }
  erb :'actors/show', locals: {roles: roles, actor: actor}
end

get '/movies' do
  order_by = params["order"]
  if order_by.nil?
    order_by = "movies.title"
    session[:direction] = "ASC"
  end
  if session[:sort_item] == order_by
    session[:direction] = flip(session[:direction])
  else
    session[:direction] = "ASC"
  end

  sql = "SELECT movies.title, movies.year, movies.rating, genres.name AS genre, studios.name AS studio
         FROM movies
         JOIN genres
         ON movies.genre_id = genres.id
         JOIN studios
         ON movies.studio_id = studios.id
         ORDER BY #{order_by} #{session[:direction]}"

  movies = db_connection { |conn| conn.exec(sql).to_a }
  session[:sort_item] = order_by
  erb :'movies/index', locals: {movies: movies}
end

get '/movies/:id' do
  movie = params["id"]
  movie_id = db_connection { |conn| conn.exec("SELECT id FROM movies WHERE title='#{movie}'")[0]['id'] }
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
