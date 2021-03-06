require "sinatra/base"
require "sinatra/reloader"
require "sinatra/flash"
require "./lib/user"
require "./lib/booking"
require "./lib/bnb"
require "./lib/calendar"
require "./lib/search"

class Makersbnb < Sinatra::Base
  enable :sessions
  enable :method_override

  configure :development do
    register Sinatra::Reloader
    register Sinatra::Flash
  end

  before do
    @user = User.find(id: session[:user_id]) if session[:user_id]
  end

  helpers do
    def truncate(text, max_chars = 100)
      if text.length > max_chars
        text[0..(max_chars - 3)] + "..."
      else
        text
      end
    end
  end

  get "/" do
    erb(:index)
  end

  get "/search" do
    @bnbs = Search.filter(
      location: params[:location], min_price: params[:min_price],
      max_price: params[:max_price], start_date: params[:start_date], end_date: params[:end_date],
    )
    erb :search
  end

  get "/user" do
    erb(:'user/index')
  end

  post "/user" do
    user = User.create(first_name: params[:first_name], last_name: params[:last_name], host: params[:host], email: params[:email], password: params[:password], password_confirmation: params[:password_confirmation])
    unless user
      flash[:notice_sign_up] = "Email already exists, or passwords did not match"
      redirect "/user"
    else
      session[:user_id] = user.id
      redirect "/"
    end
  end

  post "/log_out" do
    session[:user_id] = nil
    redirect "/"
  end

  get "/user/login" do
    erb(:"user/login")
  end

  post "/user/login" do
    user = User.log_in(email: params[:email], password: params[:password])
    unless user
      flash[:notice_login] = "Password did not match or wrong email, please try again"
      redirect(:'user/login')
    else
      session[:user_id] = user.id
      session[:previous_url] ? redirect("#{session[:previous_url]}") : redirect("/")
    end
  end

  get "/user/dashboard" do
    def find_bnb(id)
      Bnb.find(id: id)
    end

    @user_id = session[:user_id]
    @user = User.find(id: @user_id) if @user_id
    if @user.host != "f"
      @bnbs = Bnb.where(user_id: @user_id)
      @bookings = Booking.find_by_host(host_id: @user_id)
      @bookings_by_host = Booking.find_by_user(user_id: @user_id)
      erb(:'user/dashboard')
    else
      @booking = Booking.find_by_user(user_id: @user_id)
      erb(:'user/guest_dashboard')
    end
  end

  get "/user/dashboard/:id/bnb/new" do
    @user_id = params[:id]
    erb :'bnb/new'
  end

  post "/user/dashboard/:id/bnb" do
    Bnb.create(name: params[:name], location: params[:location], description: params[:description], price: params[:price], user_id: params[:id])
    redirect "user/dashboard"
  end

  get "/listings/all" do
    @bnb = Bnb.all
    erb :'listings/all'
  end

  get "/listings/bnb/:id" do
    @bnb = Bnb.find(id: params[:id])
    @user_id = session[:user_id]
    @bookings = Booking.find_by_bnb(bnb_id: params[:id])
    @calendar = Calendar.new(@bookings)
    erb :'listings/bnb'
  end

  delete "/user/dashboard/:id/bnb/:bnb_id" do
    Bnb.delete(id: params[:bnb_id])
    redirect "user/dashboard"
  end

  get "/user/dashboard/:id/bnb/:bnb_id/edit" do
    @user_id = session[:user_id]
    @bnb = Bnb.find(id: params[:bnb_id])
    erb :"bnb/edit"
  end

  post "/user/booking/:bnb_id/new" do
    if session[:user_id]
      if params[:start_date] == "" || params[:start_date].nil? || params[:end_date] == "" || params[:end_date].nil?
        flash[:notice] = "Please enter a start and end date"
        redirect("/listings/bnb/#{params[:bnb_id]}?start_date=#{params[:start_date]}&end_date=#{params[:end_date]}")
      end
      if Bnb.available?(bnb_id: params[:bnb_id], start_date: params[:start_date], end_date: params[:end_date])
        booking = Booking.create(start_date: params[:start_date], end_date: params[:end_date], bnb_id: params[:bnb_id], user_id: session[:user_id])
        flash[:notice] = "Your booking ##{booking.id} has been confirmed!"
        redirect("/listings/bnb/#{params[:bnb_id]}")
        session[:previous_url] = nil
      else
        flash[:notice] = "Sorry, those dates are unavailable"
        redirect("/listings/bnb/#{params[:bnb_id]}?start_date=#{params[:start_date]}&end_date=#{params[:end_date]}")
      end
    else
      session[:previous_url] = "/listings/bnb/#{params[:bnb_id]}?start_date=#{params[:start_date]}&end_date=#{params[:end_date]}"
      link = "<a href=/user/login>log in</a>"
      flash[:notice] = "Please #{link} to book"
      redirect("/listings/bnb/#{params[:bnb_id]}?start_date=#{params[:start_date]}&end_date=#{params[:end_date]}")
    end
  end

  patch "/user/dashboard/:id/bnb/:bnb_id" do
    Bnb.update(id: params[:bnb_id], name: params[:name], location: params[:location], description: params[:description], price: params[:price])
    redirect "user/dashboard"
  end

  delete "/user/dashboard/:id/booking/:booking_id" do
    Booking.delete(id: params[:booking_id])
    redirect "user/dashboard"
  end

  get "/user/dashboard/:id/booking/:booking_id/edit" do
    @user_id = session[:user_id]
    @booking = Booking.find(id: params[:booking_id])
    erb :"user/edit_booking"
  end

  patch "/user/dashboard/:id/booking/:booking_id" do
    Booking.update(id: params[:booking_id], start_date: params[:start_date], end_date: params[:end_date])
    redirect "user/dashboard"
  end

  get "/user/dashboard/:id/bnb/:bnb_id/booking/:booking_id/edit" do
    @user_id = session[:user_id]
    @booking = Booking.find(id: params[:booking_id])
    erb :"user/edit_booking_by_host"
  end

  patch "/user/dashboard/:id/bnb/:bnb_id/booking/:booking_id" do
    Booking.update(id: params[:booking_id], start_date: params[:start_date], end_date: params[:end_date])
    redirect "listings/bnb/#{params[:bnb_id]}"
  end

  delete "/user/dashboard/:id/bnb/:bnb_id/booking/:booking_id" do
    Booking.delete(id: params[:booking_id])
    redirect "listings/bnb/#{params[:bnb_id]}"
  end

  run! if app_file == $0
end
