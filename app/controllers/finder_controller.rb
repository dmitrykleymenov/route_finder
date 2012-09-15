class FinderController < ApplicationController
  
  def index
    #debugger
    @member = Member[session[:member_id]] if session[:member_id]
  end

  def entering
    #debugger
    session[:member_id] = (Member.find(:name => params[:member]).first.id if Member.find(:name => params[:member]).first) ||Member.create(:name => params[:member]).id
    redirect_to index_path
  end
  
  def leaving
    session[:member_id] = nil
    redirect_to index_path
  end
  
  def old_result
    #debugger
    @res = Result[params[:id]]
    session[:result_id] = @res.id
    render(:result)
  end

  def result
    member = Member[session[:member_id]] if session[:member_id]
    #dep_port = Aeroport[params[:departure]]
    #arr_port = Aeroport[params[:arrival]]
    
    res = Result.create(:member => member,
                        :search_params => params,
                        :search_at => Time.now,
                        )
    #debugger
    #@res = Result.create(:member => member,
    #                    :departure_date => convert_date(0).to_s,
    #                    :departure_place => dep_port.name,
    #                    :arrival_place => arr_port.name,
    #                    :search_at => Time.now,
    #                    )
    session[:result_id] = res.id
                        
    #route = Ohm.redis.zrangebyscore("from:#{dep_port.id}:to:#{arr_port.id}",
    #                              convert_date(0).to_time.to_i,
    #                              convert_date(1).to_time.to_i).map do |par|
    #                                [par.split(", ")]                              
    #                              end
    
    #(1..Ohm.redis.get("Aeroport:counter").to_i).each do |id| 
    #  next if (id == dep_port.id || id == arr_port.id)
    #  full_fly = []
    #  temp_arr = Ohm.redis.zrangebyscore("from:#{dep_port.id}:to:#{id}",
    #                              convert_date(0).to_time.to_i,
    #                              convert_date(1).to_time.to_i)
    #  
    #  temp_arr.each do |first|
    #    arr = first.split(", ");
    #    temp = Ohm.redis.zrangebyscore("from:#{id}:to:#{arr_port.id}",
    #                              arr[3].to_time.to_i,
    #                              arr[3].to_time.to_i + 60*60*24)
    #    temp.each do |second|
    #      full_fly << [arr, second.split(",")]
          #debugger
    #    end
    #  route+=full_fly
    #  end

    #end
    #debugger
    #@res.res_array =[] 
    #@res.res_array += [route]
    #@res.save
   # time = Benchmark.realtime do

   # end

    redirect_to :action => :old_result, :id => res.id
  end

  def find
    #debugger
    res = Result[session[:result_id]]
    @results = []
    data = Ohm.redis.get("results:#{res.id}")
    if data
      @results = Marshal.load(data)
      return
    end

    #debugger
    @results << find_flys(Aeroport[res.search_params["departure"]],
                          convert_date(res.search_params["departure_date"],0),
                          Aeroport[res.search_params["arrival"]])

    #debugger
    if res.search_params["second_route"]
      @results << find_flys(Aeroport[res.search_params["departure_2"]],
                            convert_date(res.search_params["departure_date_2"],0),
                            Aeroport[res.search_params["arrival_2"]])
    end

    Ohm.redis.set("results:#{res.id}", Marshal.dump(@results))
    #debugger
    respond_to do |format|
      format.js{}
    end
  end


#  def filtering
#    @res = Result[session[:result_id]]
#    @res.all_flys.each do |fly|
#      if parsing_params(fly, :format => :js)
#        fly.selected_result = @res
#      else
#        fly.selected_result = nil
#      end
#      fly.save
#    end
#    
#    @res.save
#    respond_to do |format|
#      format.js{}
#    end
#  end
  
  private
  
  def parsing_params(fly, par)
    if par[:format] == :html
      #debugger
      (params[:changes].to_i + 1) >= fly.number_of_tracks && params[:price].to_f >= fly.total_cost && (params[:pend_hours].to_i*3600 + params[:pend_minutes].to_i*60)  >= fly.total_pending && (params[:hours].to_i*3600 + params[:days].to_i*86400) >= fly.total_time
    elsif par[:format] == :js
      (params[:select_changes].to_i + 1) >= fly.number_of_tracks && params[:select_price].to_f >= fly.total_cost && (params[:select_pend_hours].to_i*3600 + params[:select_pend_minutes].to_i*60)  >= fly.total_pending && (params[:select_hours].to_i*3600 + params[:select_days].to_i*86400) >= fly.total_time
    end
  end
    
  def convert_date(date, difference=0)
    d = date.map{|key,value| value.to_i}
    (d[-1] = d[-1] - 1) until Date.valid_date?(*d) 
    date = Date.new(*d)
    date+difference
  end

  
  def find_flys(dep_port, dep_date, arr_port)
    max_pending_hours = 24
    route = Route.new(dep_port.name,arr_port.name) 
    route.flys = (Ohm.redis.zrangebyscore("from:#{dep_port.id}:to:#{arr_port.id}",
                                  dep_date.to_time.to_i,
                                  (dep_date+1).to_time.to_i) || []).map do |par|
                                    ff = FullFly.new 
                                    #debugger
                                    ff + Track.new(par)                   
                                  end

    #debugger
    
    time = Benchmark.realtime do
      Ohm.redis.smembers("allRoutesFrom:#{dep_port.id}").each do |id| 
        temp_dep = (Ohm.redis.zrangebyscore("from:#{dep_port.id}:to:#{id}",
                                    dep_date.to_time.to_i,
                                    (dep_date+1).to_time.to_i) || [])
        
        temp_arr = (Ohm.redis.zrangebyscore("from:#{id}:to:#{arr_port.id}",
                                  dep_date.to_time.to_i + 60*60*(4+1),
                                  (dep_date+1).to_time.to_i + 60*60*14 + 60*60*max_pending_hours) || [])
        #debugger
        temp_dep.each do |first|
          temp_arr.each do |last|
            tr_dep = Track.new(first)
            tr_arr = Track.new(last)
            if (tr_dep.arr_time + 60*60 < tr_arr.dep_time &&
                tr_dep.arr_time + 60*60*max_pending_hours > tr_arr.dep_time)
              ff = FullFly.new
              ff + tr_dep
              ff + tr_arr
              route + ff
              #debugger
            end # if
          end   # temp_arr.each
        end     # temp_dep.each
      end       # smembers.each
    end         # Benchmark.realtime
    
    #debugger
    
#=begin   
    time2 = Benchmark.realtime do
      Ohm.redis.smembers("allRoutesFrom:#{dep_port.id}").each do |first_id| 
        next if (first_id == arr_port.id)
        first_temp_arr = (Ohm.redis.zrangebyscore("from:#{dep_port.id}:to:#{first_id}",
                                    dep_date.to_time.to_i,
                                    (dep_date+1).to_time.to_i) || []).map{|str| Track.new(str)}
                                    
        Ohm.redis.smembers("allRoutesTo:#{arr_port.id}").each do |last_id|
          next if (last_id == dep_port.id || last_id == first_id)
          #debugger
          last_temp_arr = (Ohm.redis.zrangebyscore("from:#{last_id}:to:#{arr_port.id}",
                                    (dep_date+1).to_time.to_i + 60*60*12,
                                    (dep_date+4).to_time.to_i) || []).map{|str| Track.new(str)}
          
          middle_temp_arr = (Ohm.redis.zrangebyscore("from:#{first_id}:to:#{last_id}",
                                    (dep_date).to_time.to_i + 60*60*5,
                                    (dep_date+1).to_time.to_i + 60*60*max_pending_hours) || []).map{|str| Track.new(str)}
          #debugger
          first_temp_arr.each do |first|
            last_temp_arr.each do |last|
              middle_temp_arr.each do |middle|
                #debugger
                if (middle.arr_time + 60*60 < last.dep_time  &&
                    first.arr_time + 60*60 < middle.dep_time &&
                    first.arr_time + 60*60*max_pending_hours > middle.dep_time && 
                    middle.arr_time + 60*60*max_pending_hours > last.dep_time)
                 
                  #debugger
                  ff = FullFly.new
                  ff + first
                  ff + middle
                  ff + last
                  route + ff
                #elsif middle.arr_time + 60*60 > last.dep_time
                  #debugger
                #  break;
                end # if
              end   # middle_temp_arr.each
            end     # last_temp_arr.each
          end       # first_temp_arr.each
        end         # smembers airports with flys to arrival place                 
      end           # smembers airports with flys from dep place
    end             # Benchmark.realtime
#=end
  #debugger
  route.flys.sort_by!{|fly| fly.total_cost}
  route
  end
  
end