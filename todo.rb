require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def todo_list_completed?(list)
    list[:todos].size > 0 && list[:todos].all? { |todo| todo[:completed] }
  end

  def num_of_completed_todos(list)
    list[:todos].count { |todo| todo[:completed] }
  end

  def list_class(list)
    "complete" if todo_list_completed?(list)
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| todo_list_completed?(list) }

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View all the lists
get "/lists" do
  #array of hashes, containing list name and array of todos.
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "The list name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "The list name already exists. list name must be unique."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created successfully."
    redirect "/lists"
  end
end

# Render a page view of a single list and its ToDo's.
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

# Change the name of an existing list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :edit_list, layout: :layout
end

# Update an existing list's name
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = session[:lists][id]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list name has been edited successfully."
    redirect "/lists/#{id}"
  end
end

# Delete a list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  destroyed_list = session[:lists].delete_at(id)
  session[:success] = "The '#{destroyed_list[:name]}' list has been deleted."
  redirect "/lists"
end

def error_for_todo_name(name)
  if !(1..100).cover? name.size
    "The to-do item must be between 1 and 100 characters."
  end
end

# Create a todo
post "/lists/:list_id/todos" do
  todo_name = params[:todo].strip
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  error = error_for_todo_name(todo_name)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: todo_name, completed: false}
    session[:success] = "The to-do item has been added successfully."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo
post "/lists/:list_id/todos/:todo_id/destroy" do
  todo_id = params[:todo_id].to_i
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  destroyed_todo = @list[:todos].delete_at(todo_id)
  session[:success] = "The '#{destroyed_todo[:name]}' to-do has been deleted."
  redirect "/lists/#{@list_id}"
end

# Check or uncheck a todo as completed
post "/lists/:list_id/todos/:todo_id" do
  todo_id = params[:todo_id].to_i
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed
  session[:success] = "The '#{@list[:todos][todo_id][:name]}' to-do has been udpated."

  redirect "/lists/#{@list_id}"
end

# Mark all todos as completed
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "The all of the to-do's have been updated."

  redirect "/lists/#{@list_id}"
end