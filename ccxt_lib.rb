#!/usr/bin/ruby
#(c) 2019 jan 26. by sacarlson  sacarlson_2000@yahoo.com aka Scott Carlson aka scotty.surething...
# This is the support lib for ccxt-server.rb
# it contains the client side drivers to ccxt-rest servers and also direct ruby drivers to a number of crypto and fiat exchanges
# that can optionaly be used for customized ccxt-server.rb or other apps

require 'json'
require 'rest-client'

# start params configs **********************

  params = {}  
  params["feed_crypto"] = ["BTC","XLM","USDT","USD","ETH","XRP"]
  params["feed_other"] = ["THB","USD","NGN","XOF","INR"]
  params["exchange_feed_key"] = "find_needed_key" 
  params["last_price"] = {}

  
# max_diff is the max difference bettween two currency api feeds that are compared to verify that data is acurate within reason
# presently compares yahoo and openexchange and now coinbase and polonix 
$max_diff = 0.02
#$max_diff = 0.035

# global values for ccxt configs, I know it sucks but to keep compatible with what we already had
 $ccxt_config = {}
 # standard ccxt-rest port
 #$ccxt_config["url"] =  "http://localhost:3000"
 # need to change real ccxt-rest port to 3030 to support kelp that is hard coded to only support 3000 
 # make sure ENV PORT=3030 before running ccxt-rest to support this
 $ccxt_config["url"] =  "http://localhost:3030"
 # ruby ccxt-server
 #$ccxt_config["url"] =  "http://localhost:8080"
 # to see all exchanges supported by ccxt: curl http://localhost:3000/exchanges
 $ccxt_config["exchange"] = "kraken"
 $ccxt_config["apikey"] = "nokey"
 $ccxt_config["secret"] = "nosecret"
 $ccxt_config["params"] = params

#end configs ************************************
    

puts "params: #{params}"


def percent_diff(x,y)
  #return percent difference between two numbers
  # number will always return positive or zero
  return (100*(y.to_f - x.to_f) / x.to_f).abs
end

def split_assetpair(assetpair)
   array = assetpair.split("_")
   puts "base_code sell asset: #{array[0]}"
   puts "currency_code buy asset: #{array[1]}"
   return array
end


def check_feedable(currency,base,feed_array)
  puts "check_feedable"
  puts "feed_array: #{feed_array}"
  a = false
  b = false
  if currency == base
    puts "currency and base are the same so not feedable"
    return false
  end
  feed_array.each { |ccode|
    if ccode == currency
      a = true
    end
    if ccode == base
      b = true
    end
  }
  if a && b 
    return true
  else
    puts "no feed found for this set #{currency} and #{base} on this feed_array"
    return false
  end 
end

def get_any_exchangerate(currency_code, base_code,params=$ccxt_config["params"])
  puts "get_any_exchangerate started"
  if currency_code == base_code
    puts "currency_code and base_code are the same, will return 1"
    return 1
  end
  timestamp = (Time.now.to_i - 240).to_s
  puts "timestamp: #{timestamp}"
  asset_pair = base_code + "_" + currency_code
  puts "asset_pair: #{asset_pair}"
  if !params["last_price"][asset_pair].nil?
    puts "we already had exchange rate for this asset pair of: #{params["last_price"][asset_pair]}"
    return params["last_price"][asset_pair]
  end
  # check to see if we already collected this data within the last 60 sec (now 240 sec 4 min), if so give us that
  #result = get_mss_server_feed_exchangerate_min(currency_code,base_code,timestamp )
  #if result.to_f > 0
  #  return result.to_f
  #end
  #return the rate of currency_code exchange with base_code 
  # will auto pick needed feed determined by lists in params["feed_crypto"] and params["feed_other"]
  $disable_record_feed = params["disable_record_feed"]
  if check_feedable(currency_code,base_code,params["feed_crypto"])
    #puts "poloniex feed selected"
    puts "coinbase feed selected"
    #result_exch = get_poloniex_exchangerate(currency_code,base_code)
    #result = convert_polo_to_liquid(result_exch, 0.0)
    #result = get_poloniex_exchange_liquid(currency_code,base_code,params["min_liquid"])
    #result = get_poloniex_exchangerate(currency_code,base_code)
     #been having problems with poloniex feed will try coinbase but not sure how accurate coinbase is so add profit margin to 5% also instead of 2.5%
    #result = get_coinbase_exchangerate(currency_code,base_code)
    # get_crypto has feed from coinbase and polonix to verify they are close match
    result = get_crypto_exchangerate(currency_code,base_code)
  else
    if check_feedable(currency_code,base_code,params["feed_other"])
      puts "feed_other: #{params["feed_other"]}"
      result = get_exchangerate(currency_code,base_code,params["exchange_feed_key"])
    else
      puts "feed_other: #{params["feed_other"]}"
      puts " we have no data feed for this currency pair #{currency_code}  and #{base_code} so can't trade"
      return 0
    end
  end
  puts "get_exchangerate result.keys: #{result.keys}"
  puts "get_exchangerate result: #{result}"
  if result["status"] == "fail"
     puts "get_exchangerate status fail,  will not trade this data in auto_trade_offer_set"
     return 0
  else
    puts "get_exchangerate status OK,  will trade"
  end
  #puts "last_rate: #{$last_rate}"
  params["last_price"][asset_pair] = result["rate"].to_f
  return result["rate"].to_f
end



 def get_crypto_exchangerate(currency_code,base_code)
    #get the best 2 crypto feed prices and verify they are a close match
    # if rate returned from each is different more than our spec then return 0 and fail status
    #get_exchangerate result: {"service"=>"coinbase", "status"=>"pass", "rate"=>"0.10735542", "base"=>"XLM", "currency_code"=>"USD", "last_updated"=>1547257829}
    # preference returned is now polonex due to the 10% spike detected on coinbase the day before that wasn't seen on kraken 
    # $max_diff was .008
    #result_primary = get_poloniex_exchangerate(currency_code,base_code)
    result_primary = get_kraken_exchangerate(currency_code, base_code)
    result_second = get_poloniex_exchangerate(currency_code,base_code)
    #result_second = get_coinbase_exchangerate(currency_code,base_code)
    max_diff = $max_diff
    
    if result_second["status"] == "fail"
      result_primary["status"] = "pass1"
      return result_primary
    end
    rat = result_second["rate"].to_f/result_primary["rate"].to_f
    if rat > 1
      diff = (rat -1)
    else
      diff = (1 - rat)
    end
  
    puts "diff: " + diff.to_s
    result_primary["diff"] = diff
    #result_primary["status"] = "pass"
    if diff > $max_diff
      result_primary["status"] = "fail"
      puts "$max_diff rate exeded at: #{diff}"
    else
      result_primary["status"] = "pass"      
    end 
    result_primary["diff"] = diff
    return result_primary
  end

def get_exchangerate(currency_code,base_code,key="")
  # this is used to get fiat currency rates from two sources, checks to verify they are close match with returned status
  # this is not used for crypto price lookups
  # set to default exchange rate feed source
  #  this version disables yahoo feed as it seems yahoo feed is broken at the moment
  data_2 = get_openexchangerates(currency_code,base_code,key)
  #record_feed(data_2)
  data_2["status"] = "pass"
  return data_2
end

def get_yahoo_finance_exchangerate(currency_code,base_code)
 # note it seems USD/THB is delayed by about 30 minutes and in fact buy random time windows so be careful using this data
 # some others are delayed by much more like THB/USD can be 6 hours or more delayed  
 #https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.xchange%20where%20pair%20in%20(%22USDTHB%22)&format=json&diagnostics=true&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=
    puts "get_yahoo_finance_exchangerate"
    puts "currency_code: #{currency_code}" 
    puts "base_code: #{base_code}"
    # if more than one currency is needed
    url_start_b = "https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.xchange%20where%20pair%20in%20"
    url_end_b = "&format=json&diagnostics=true&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback="
    # with just a single currency
    url_start = "https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.xchange%20where%20pair%20in%20(%22"
    url_end = "%22)&format=json&diagnostics=true&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback="
    #puts " currency_code: #{currency_code}"
    #puts " base_code: #{base_code}"
    send = url_start + base_code + currency_code + url_end
    #send = url_start_b +'(%22' + base_code + currency_code + '%22)' +  url_end_b
    # to lookup more than one currency at the same time
    #send = url_start_b +'(%22USDEUR%22,%20%22USDJPY%22)' +  url_end_b
    puts "yahoo sending:  #{send}"
    begin
      postdata = RestClient.get send
    rescue => e
      puts "fail in get_yahoo_finance_exchangerate at RestClient.get  error: #{e}"
      data_out = {}
      data_out["service"] = "yahoo"
      data_out["status"] = "fail"
      puts "yahoo data_out: #{data_out}"
      return  data_out
    end
    #puts "postdata: " + postdata
    data = JSON.parse(postdata)
    data_out = {}
    data_out["currency_code"] = currency_code
    data_out["rate"] = data["query"]["results"]["rate"]["Rate"].to_s
    data_out["datetime"] = data["query"]["results"]["rate"]["Date"].to_s + "T" + data["query"]["results"]["rate"]["Time"].to_s
    data_out["ask"] = data["query"]["results"]["rate"]["Ask"]
    data_out["bid"] = data["query"]["results"]["rate"]["Bid"]
    data_out["base"] = base_code
    data_out["service"] = "yahoo"
    puts "yahoo data_out: #{data_out}"
    return data_out
end


def get_currencylayer_exchangerate(currency_code,key)
  #  this does not work yet for reasons uknown probly headers needed but not sure what headers
  # this one when free will only do lookups compared to USD, also limits to 1000 lookup per month so only 1 per hour
  # but can lookup more than one currency at a time with coma delimited string
  # I see nothing better bettween apilayer.net and https://openexchangerates.org so we are no longer trying to support this one
  # if someone see's anything better here maybe we will again attempt to add it.
  #http://apilayer.net/api/live?access_key=fe2f96f017b702fec2f0c1e8092ae88f&currencies=THB,AUD&format=1

  url_start = "http://apilayer.net/api/live?access_key="
  url_end = "&format=1"
  send = url_start + key + "&currencies=" + currency_code +  url_end
  #send = "https://www.funtracker.site/map.html"
    #puts "sending:  #{send}"
    begin
      #postdata = RestClient.get send , :user_agent => "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:47.0) Gecko/20100101 Firefox/47.0"
      postdata = RestClient.get send , { :Accept => '*/*', 'accept-encoding' => "gzip, deflate", :user_agent => "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:47.0) Gecko/20100101 Firefox/47.0"}
    rescue => e
      puts "fail in get_currencylayer_exchangerate at RestClient.get  error: #{e}"
      data_out = {}
      data_out["service"] = "currencylayer"
      data_out["status"] = "fail"
      return  data_out
    end
    #puts "postdata: " + postdata
    data = JSON.parse(postdata)
    data["status"] = "pass"
    data["service"] = "currencylayer"
    return data
end

def get_ccxt_exchangerate(currency_code, base_code)
  #ccxt-rest support
  # first POST sets up ccxt id, no real apikey and secrets needed as we use just public parts of ccxt but the id is still needed
  #curl -X POST http://localhost:3000/exchanges/kraken -d '{"id":"myccxt","apikey":"mYapIKEy","secret":"6d792061706920736563726574"}'
  # then we lookup the ticker trade pair in this case "xlm/usd" using the myccxt id
  #$curl -X POST http://localhost:3000/exchanges/kraken/myccxt/fetchTicker -d '["XLM/USD"]'
  # return gives us this expected json output from real ccxt-server
#{"symbol":"XLM/USD","timestamp":1548755659674,"datetime":"2019-01-29T09:54:19.674Z","high":0.088403,"low":0.080199,"bid":0.081621,"ask":0.081694,"vwap":0.08419594,"open":0.085756,"close":0.081941,"last":0.081941,"baseVolume":4814300.20837873,"quoteVolume":405344.53148664307,"info":{"a":["0.08169400","1839","1839.000"],"b":["0.08162100","907","907.000"],"c":["0.08194100","90.00000000"],"v":["1623468.37553117","4814300.20837873"],"p":["0.08325980","0.08419594"],"t":[290,855],"l":["0.08019900","0.08019900"],"h":["0.08619000","0.08840300"],"o":"0.08575600"}}
  #url example "http://localhost:3000"
  url = $ccxt_config["url"]
  exchange = $ccxt_config["exchange"]
  #puts "exchange: #{exchange}"
  apikey = $ccxt_config["apikey"]
  secret = $ccxt_config["secret"] 
  flag_invert = 0
  puts "base_code: #{base_code}"
  puts "currency_code: #{currency_code}"
  if base_code == "USDT"
    base_code = "USD"
  end
  if currency_code == "USDT"
    currency_code = "USD"
  end
  if base_code == "USD" || base_code == "BTC"    
     puts "base_code ok"      
  else    
    puts "flag_invert 1 rotate base and currency"
    flag_invert = 1
    if !(currency_code == "USD" || currency_code == "BTC")
      puts "base_code and currency_code not USD or BTC return 0"
      return 0
    end
    temp_base_code = base_code
    base_code = currency_code
    currency_code = temp_base_code    
  end
  
  if currency_code == "USD" && $ccxt_config["exchange"] == "poloniex"
    currency_code = "USDT"
  end
  if base_code == "USD" && $ccxt_config["exchange"] == "poloniex"
    base_code = "USDT"
  end
  pre_url = url + "/exchanges/" + exchange 
  pre_payload = '{"id":"myccxt","apikey":"' + apikey + '","secret":"'+ secret + '"}'
  fetch = "/exchanges/" + exchange + "/myccxt/fetchTicker"
  final_url = url + fetch  
  payload = '["' + currency_code + '/' + base_code + '"]'  
  puts "pre_payload =  #{pre_payload}"
  puts "pre_url = #{pre_url}"
  begin
      postdata = RestClient::Request.execute(method: :post, url: pre_url, payload: pre_payload, timeout: 10)
    rescue => e
      puts "fail in get_ccxt_exchange at RestClient post  error: #{e}"
      data_out = {}
      info = {}
      info["service"] = "ccxt_" + exchange
      info["status"] = "fail"
      info["error"] = e
      data_out["info"] = info
      puts "ccxt data_out: #{postdata}"
      return  data_out
  end
  #puts "postdata: " + postdata
  #data = JSON.parse(postdata)
  #puts "data: #{data}" 
  puts ""
  puts "final_url: #{final_url}"
  puts "final_payload: #{payload}"
  begin
    #final_url = "http://localhost:3000/exchanges/kraken/myccxt/fetchMarkets"
    postdata = RestClient::Request.execute(
      :method => :post,
      :url => final_url,
      :payload => payload,
      :timeout => 10,
      #:headers => {:accept => :html,'Accept-Encoding' => ''}
    )    
    rescue => e
      puts "fail2 in get_ccxt_exchangerate at RestClient  error: #{e}"
      data_out = {}
      info = {}
      info["service"] = "ccxt_" + exchange
      info["status"] = "fail"
      info["error"] = e
      data_out["info"] = info
      return  data_out
  end
  #puts "postdata: " + postdata
  data = JSON.parse(postdata)
  #puts "data: #{data}"
  #{"symbol":"XLM/USD","timestamp":1547971723027,"datetime":"2019-01-20T08:08:43.027Z","high":0.109876,"low":0.106,"bid":0.10664,"ask":0.10681,"vwap":0.10762915,"open":0.10698,"close":0.106631,"last":0.106631,"baseVolume":3491949.44291745,"quoteVolume":375835.5503841787,"info":{"a":["0.10681000","9119","9119.000"],"b":["0.10664000","12000","12000.000"],"c":["0.10663100","1854.11799607"],"v":["1222498.78412874","3491949.44291745"],"p":["0.10736107","0.10762915"],"t":[165,718],"l":["0.10651000","0.10600000"],"h":["0.10780000","0.10987600"],"o":"0.10698000"}}
  # change to set rate at center of bid and ask instead of last traded price
  rate=((data["ask"].to_f-data["bid"].to_f)/2)+data["bid"].to_f
  #puts ""
  #puts "ask: #{data["ask"]}"
  #puts "rate: #{rate}"
  #rate = 1.0
  #info = {}
  data["info"]["service"] = "ccxt_" + exchange
  data["info"]["status"] = "pass"
  # not sure why invert is reversed with ccxt but it is so fixed here
  if flag_invert == 1   
      #data_out["rate"] = sprintf('%.8f',1.0/rate)
      data["rate"] = sprintf('%.8f',rate) 
      data["base"] = base_code
      data["currency_code"] = currency_code
    else
      #data_out["rate"] = sprintf('%.8f',rate)    
      data["rate"] = sprintf('%.8f',1.0/rate)
      data["base"] = currency_code
      data["currency_code"] = base_code
    end
  #puts "data: #{data}"
  return data
end

def get_averge_feed(currency_code,base_code,exchanges=[["kraken",66]],mode="weighted_averge")
  # exchanges is an array of arrays that holds a group or two element arrays that contain the name of the exchange and it's trading weight
  # example: ["kraken",75] would be the kraken exchange with trading weight of 75
  # the weight value can be in percent or in the estimated daily volume of the exchanges.  I'm looking at percent as what I plan to use normally.
  #exchanges = [["kraken",66],["poloniex",33]]
  # in this case with kraken at 66 and poloniex at 33 is because I know that kraken has about 2X the trading volume of poloniex so it
  # should have two times the trading weight.  I guess the values of 2 and 1 would also work in this case.

  #mode can be set to fallback or defaulted weighted_averge
  # in fallback mode we start with the first exchange in the exchange array and ignore trading weight values
  # if a feed fails it will just try and get the next feed in line in the array list
  # the first feed that works is returned as the results in standard expanded ccxt format, if all fail then we return result as failure
  # with resulting added total_weights = 0 assuming you set some number in each weights field in exchanges array of at least 1
  #mode = "fallback"||"weighted_averge"
  # at this point we will force port 3030 to be used as we have ccxt-server set to listen to 3000 before we run get_averge_feed. at some point might want to move this setting
  $ccxt_config["url"] =  "http://localhost:3030"
  rates = {}
  total_weights = 0
  total_weighted = 0
  max_rate = 0
  min_rate = 999999
  exchanges.each do |exchange|
    puts "exchange name #{exchange[0]}"
    puts "exchange weight: #{exchange[1]}"
    $ccxt_config["exchange"] = exchange[0]
    result = get_ccxt_exchangerate(currency_code, base_code)
    puts "result: #{result}"
    rates[exchange[0]] = result["rate"]
    puts "info: #{result["info"]}"
    puts "info status: #{result["info"]["status"]}"
    if result["info"]["status"] == "pass"
      if max_rate < result["rate"].to_f
         max_rate = result["rate"].to_f
      end
      if min_rate > result["rate"].to_f
         min_rate = result["rate"].to_f
      end
      total_weights = total_weights + exchange[1]
      if mode == "fallback"
        puts "now in fallback mode"
        result["total_weights"] = total_weights
        return result
      end
      total_weighted = (result["rate"].to_f*exchange[1]) + total_weighted      
    end
  end
  
  puts "total_weighted: #{total_weighted}"
  puts "total_weights: #{total_weights}"  
  puts "rates: #{rates}"  
  send_results = {}
  info = {}
  if total_weights > 0
    total_weighted_averge = (total_weighted/total_weights).round(8)
    puts "total_weighted_averge: #{total_weighted_averge}"
    info["status"] = "pass"  
    info["rates"] = rates
    info["total_weights"] = total_weights
    info["averge_rate"] = total_weighted_averge
    info["max_rate"] = max_rate
    info["min_rate"] = min_rate
    send_results["info"] = info
    send_results["bid"] = total_weighted_averge
    send_results["ask"] = total_weighted_averge
    send_results["last"] = total_weighted_averge
    send_results["rate"] = total_weighted_averge
  else
    info["status"] = "fail"
    send_results["info"] = info
  end
  return send_results
  #{"info"=>{"rates"=>{"kraken"=>"12.24679746", "poloniex"=>"12.21171499"}, "total_weights"=>99, "averge_rate"=>12.2351033}, "bid"=>12.2351033, "ask"=>12.2351033, "last"=>12.2351033, "averge_rate"=>12.2351033, "rate"=>12.2351033}
end


def get_kraken_exchangerate(currency_code, base_code)
  # currency_code = "USD"
  # base_code = "XLM"    
  # looks must end in ZUSD or ZEUR or XBTC??  pair ZUSDXXLM won't work error EQuery:Unknown asset pair
  #https://api.kraken.com/0/public/Ticker?pair=XXLMZUSD  this works to see bellow

  #{"error":[],"result":{"XXLMZUSD":{"a":["0.10987900","3752","3752.000"],"b":["0.10938600","300","300.000"],"c":["0.10935100","700.00000000"],"v":["433942.48844710","1605788.12327216"],"p":["0.10972769","0.10601993"],"t":[257,652],"l":["0.10516900","0.10389100"],"h":["0.11188200","0.11188200"],"o":"0.10538300"}}}

  # result "c" looks to be the last price or rate we want, the other data other then error we don't need
  url_start = "https://api.kraken.com/0/public/Ticker?pair="
  flag_invert = 0
    if base_code == "USD" || base_code == "BTC"
      puts "base_code ok"
    else
      if currency_code == "USD" || currency_code == "BTC"
        puts "flag_invert 1 rotate base and currency"
        flag_invert = 1
        temp_base_code = base_code
        base_code = currency_code
        currency_code = temp_base_code
      else
        puts "base_code and currency_code not USD or BTC return 0"
        return 0
      end
    end
    if base_code == "USD"
      base_code = "ZUSD"
    end
    if base_code == "BTC"
      base_code = "XBTC"
    end
    currency_code = "X"+currency_code

    url_start = "https://api.kraken.com/0/public/Ticker?pair="
    asset_pair = currency_code+base_code
    send = url_start + currency_code+base_code
  
    puts "kraken sending:  #{send}"
  
    begin
      #postdata = RestClient.get send
      postdata = RestClient::Request.execute(method: :get, url: send,timeout: 10)
    rescue => e
      puts "fail in get_kraken_exchangerate at RestClient.get  error: #{e}"
      data_out = {}
      data_out["service"] = "kraken"
      data_out["status"] = "fail"
      puts "kraken data_out: #{data_out}"
      return  data_out
    end
    #puts "postdata: " + postdata
    data = JSON.parse(postdata)
    #puts "data: #{data}"
    #data: {"error"=>[], "result"=>{"XXLMZUSD"=>{"a"=>["0.11120300", "1127", "1127.000"], "b"=>["0.11077800", "3751", "3751.000"], "c"=>["0.11103500", "50.50000000"], "v"=>["804773.53035110", "1867617.36261070"], "p"=>["0.11021216", "0.10700521"], "t"=>[308, 679], "l"=>["0.10516900", "0.10389100"], "h"=>["0.11188200", "0.11188200"], "o"=>"0.10538300"}}}
    #puts data["result"][asset_pair]
    #{"a"=>["0.11102200", "22166", "22166.000"], "b"=>["0.11077300", "61", "61.000"], "c"=>["0.11103500", "50.50000000"], "v"=>["804773.53035110", "1867617.36261070"], "p"=>["0.11021216", "0.10700520"], "t"=>[308, 679], "l"=>["0.10516900", "0.10389100"], "h"=>["0.11188200", "0.11188200"], "o"=>"0.10538300"}

    data_out = {}
    data_out["service"] = "kraken"
    if data["error"].length > 0
      data_out["status"] = "fail"
      data_out["error"] = data["error"]
      return data_out
    end
    # change to set rate at center of bid and ask instead of last traded price
    rate=((data["result"][asset_pair]["a"][0].to_f-data["result"][asset_pair]["b"][0].to_f)/2)+data["result"][asset_pair]["b"][0].to_f
    data_out["status"] = "pass"
    #data_out["rate"] = price
    if flag_invert == 0
      #data_out["rate"] = sprintf('%.8f',data["result"][asset_pair]["c"][0].to_f)
      #data_out["rate"] = sprintf('%.8f',1.0/data["result"][asset_pair]["c"][0].to_f)
      data_out["rate"] = sprintf('%.8f',1.0/rate)    
      data_out["base"] = base_code
      data_out["currency_code"] = currency_code
    else
      #data_out["rate"] = sprintf('%.8f',1.0/data["result"][asset_pair]["c"][0].to_f)
      #data_out["rate"] = sprintf('%.8f',data["result"][asset_pair]["c"][0].to_f)
      data_out["rate"] = sprintf('%.8f',rate)
      data_out["base"] = currency_code
      data_out["currency_code"] = base_code
    end
    #data_out["last_updated"] = data["data"]["1"]["last_updated"]
    puts "price: #{data_out["rate"]}"
    puts data_out
    return data_out
 end

def get_coinbase_exchangerate(currency_code,base_code)
  #note at present this only works with base_code = USD or BTC or must have USD or BTC as currency_code
  #https://api.coinmarketcap.com/v2/ticker/?convert=XLM&limit=1
    flag_invert = 0
    if base_code == "USD" || base_code == "BTC"
      puts "base_code ok"
    else
      if currency_code == "USD" || currency_code == "BTC"
        flag_invert = 1
        temp_base_code = base_code
        base_code = currency_code
        currency_code = temp_base_code
      else
        puts "base_code and currency_code not USD or BTC return 0"
        return 0
      end
    end
    url_start = "https://api.coinmarketcap.com/v2/ticker/?convert="
    url_end = "&limit=1"
    send = url_start + currency_code + url_end
  
    puts "coinbase sending:  #{send}"
    begin
      #postdata = RestClient.get send
      postdata = RestClient::Request.execute(method: :get, url: send,timeout: 10)
    rescue => e
      puts "fail in get_coinbase_exchangerate at RestClient.get  error: #{e}"
      data_out = {}
      data_out["service"] = "coinbase"
      data_out["status"] = "fail"
      puts "coinbase data_out: #{data_out}"
      return  data_out
    end
    #puts "postdata: " + postdata
    data = JSON.parse(postdata)
    puts "data:"
    #puts data["data"]["1"]["quotes"][currency_code]["price"]
    puts data["data"]["1"]["quotes"]["USD"]["price"]
    price_btc = data["data"]["1"]["quotes"][currency_code]["price"]
    price_btc_usd = data["data"]["1"]["quotes"]["USD"]["price"]

    if base_code == "USD"
      #price = price_btc_usd/price_btc
      price = price_btc/price_btc_usd
    else
      #price = price_btc
      price = price_btc
    end
    data_out = {}
    data_out["service"] = "coinbase"
    data_out["status"] = "pass"
    #data_out["rate"] = price
    if flag_invert == 0
      data_out["rate"] = sprintf('%.8f',price.to_f)
      data_out["base"] = base_code
      data_out["currency_code"] = currency_code
    else
      data_out["rate"] = sprintf('%.8f',1.0/price.to_f)
      data_out["base"] = currency_code
      data_out["currency_code"] = base_code
    end
    data_out["last_updated"] = data["data"]["1"]["last_updated"]
    puts "price: #{price}"
    puts data_out
    return data_out
end

def get_poloniex_exchangerate(currency_code,base_code)
  #https://poloniex.com/public?command=returnOrderBook&currencyPair=BTC_STR
  # see: https://www.poloniex.com/support/api/ for details
  puts "get_poloniex_exchangerate"
  puts "currency_code: #{currency_code}"
  puts "base_code: #{base_code}"
  if currency_code == "XLM" || currency_code == "native"
    currency_code_send = "STR"
  else
    currency_code_send = currency_code
  end
  if base_code == "XLM" || base_code == "native"
    base_code_send = "STR"
  else
    base_code_send = base_code
  end

  if currency_code == "USD" 
    currency_code_send = "USDT"
  end
    
  if base_code == "USD" 
    base_code_send = "USDT"
  end
  if base_code_send == currency_code_send
    puts "base_code_send == currency_code_send will return 1"
    return 1
  end
  #url_start = "https://poloniex.com/public?command=returnOrderBook&currencyPair="
  url_start = "https://poloniex.com/public?command=returnTicker"
  url_end = ""
  #send = url_start + base_code_send + "_" + currency_code_send 
  send = url_start 
  #puts "sending:  #{send}"
  begin
    postdata = RestClient.get send , { :Accept => '*/*', 'accept-encoding' => "gzip, deflate", :user_agent => "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:47.0) Gecko/20100101 Firefox/47.0"}
  rescue => e
    puts "fail in get_poloniex_exchangerate at RestClient.get  error: #{e}"
    data_out = {}
    data_out["service"] = "poloniex.com"
    data_out["status"] = "fail"
    return  data_out
  end
  #puts "postdata: " + postdata
  data = JSON.parse(postdata)
  #puts "data: #{data}"
  data_ret = {}
  data_ret["status"] = "pass"  
  if base_code_send == "BTC" || base_code_send == "USDT"
    if base_code_send == "BTC" && currency_code_send == "USDT"
       obj_key = currency_code_send + "_" + base_code_send
       rate = ((data[obj_key]["highestBid"].to_f-data[obj_key]["lowestAsk"].to_f)/2)+data[obj_key]["lowestAsk"].to_f
       puts "obj_key: #{obj_key}"
       #data_ret["rate"] = sprintf('%.8f',data[obj_key]["last"].to_f)
       data_ret["rate"] = sprintf('%.8f',rate)
       data_ret["ask"] = sprintf('%.8f',data[obj_key]["lowestAsk"].to_f)
       data_ret["bid"] = sprintf('%.8f',data[obj_key]["highestBid"].to_f)
    else 
      obj_key = base_code_send + "_" + currency_code_send
      rate = ((data[obj_key]["highestBid"].to_f-data[obj_key]["lowestAsk"].to_f)/2)+data[obj_key]["lowestAsk"].to_f
      puts "obj_key: #{obj_key}"
      #data_ret["rate"] = sprintf('%.8f',1.0/data[obj_key]["last"].to_f)
      data_ret["rate"] = sprintf('%.8f',1.0/rate)
      data_ret["ask"] = sprintf('%.8f',1.0/data[obj_key]["highestBid"].to_f)
      data_ret["bid"] = sprintf('%.8f',1.0/data[obj_key]["lowestAsk"].to_f)
    end
  else
    obj_key = currency_code_send + "_" + base_code_send
    puts "obj_key: #{obj_key}"
    rate = ((data[obj_key]["highestBid"].to_f-data[obj_key]["lowestAsk"].to_f)/2)+data[obj_key]["lowestAsk"].to_f
    data_ret["rate"] = sprintf('%.8f',rate)     
    data_ret["ask"] = sprintf('%.8f',data[obj_key]["lowestAsk"].to_f)
    data_ret["bid"] = sprintf('%.8f',data[obj_key]["highestBid"].to_f)
  end
  data_ret["service"] = "poloniex.com"
  data_ret["base"] = base_code
  data_ret["currency_code"] = currency_code
  data_ret["datetime"] = Time.now.to_s
  puts "data_ret: #{data_ret}"
  #record_feed(data_ret)
  return data_ret
end

def get_poloniex_exchangerate_orderbook(currency_code,base_code)
  #https://poloniex.com/public?command=returnOrderBook&currencyPair=BTC_STR
  # see: https://www.poloniex.com/support/api/ for details
  
  if currency_code == "XLM" || currency_code == "native"
    currency_code_send = "STR"
  else
    currency_code_send = currency_code
  end
  if base_code == "XLM" || base_code == "native"
    base_code_send = "STR"
  else
    base_code_send = base_code
  end
  url_start = "https://poloniex.com/public?command=returnOrderBook&currencyPair="
  url_end = ""
  send = url_start + base_code_send + "_" + currency_code_send 
  #send = url_start + currency_code_send + "_" + base_code_send
  #puts "sending:  #{send}"
  begin
    postdata = RestClient.get send , { :Accept => '*/*', 'accept-encoding' => "gzip, deflate", :user_agent => "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:47.0) Gecko/20100101 Firefox/47.0"}
  rescue => e
    puts "fail in get_openexchangerate at RestClient.get  error: #{e}"
    data_out = {}
    data_out["service"] = "openexchangerates.org"
    data_out["status"] = "fail"
    return  data_out
  end
  #puts "postdata: " + postdata
  data = JSON.parse(postdata)
  data_out["status"] = "pass"
  data["service"] = "poloniex.com"
  data["base"] = base_code
  data["currency_code"] = currency_code
  return data
end

#  data as seen from: https://poloniex.com/public?command=returnOrderBook&currencyPair=BTC_STR
#"asks":[["0.00000350",279686.42305454],["0.00000351",89018.26064602],["0.00000352",514346.31778051],["0.00000353",132533.55189335],["0.00000354",122766.37862908],["0.00000355",320471.11853559],["0.00000356",20000],["0.00000357",21198.2],["0.00000358",20000],["0.00000359",110000],["0.00000360",21156.00378728],["0.00000361",147639.69514127],["0.00000362",325719.00666655],["0.00000363",407287.46594513],["0.00000364",387443.86603574],["0.00000365",503595.53528734],["0.00000366",34675.82356483],["0.00000367",489740.86461743],["0.00000368",2792185.4781983],["0.00000369",125635.42444457],["0.00000370",12169.01944962],["0.00000371",106565.2654594],["0.00000372",25731.90331445],["0.00000373",100416.701145],["0.00000374",100433.98972434],["0.00000375",34501.7646708],["0.00000376",199535.58534803],["0.00000377",264268],["0.00000378",105228.95529689],["0.00000379",346858.2408121],["0.00000380",1167539.8296809],["0.00000381",7094.18218139],["0.00000382",2750.68870523],["0.00000383",1183.73976116],["0.00000386",500],["0.00000387",299733.17164878],["0.00000388",499250.5],["0.00000389",21039.69400478],["0.00000390",457047.50064103],["0.00000391",2637.74428087],["0.00000392",181.1892992],["0.00000393",1500],["0.00000394",305174.8239911],["0.00000395",184333.63198436],["0.00000396",596639.04],["0.00000397",5925.38094307],["0.00000398",90398.85896785],["0.00000400",435847.55605688],["0.00000401",57680.21761456],["0.00000406",26083.49772116]],"bids":[["0.00000344",1165.64244186],["0.00000343",174542.14303209],["0.00000342",300438.98276001],["0.00000341",395092.23294599],["0.00000340",1545465.4025835],["0.00000339",25318.58407079],["0.00000338",616745.56508876],["0.00000337",28745.99680754],["0.00000336",239219.29600937],["0.00000335",186349.87489555],["0.00000334",1073137.0640403],["0.00000333",2193310.8301359],["0.00000332",126321.09274824],["0.00000331",30642.68137558],["0.00000330",756751.18370449],["0.00000329",212748.01443768],["0.00000328",146800.13167322],["0.00000327",162853.98236137],["0.00000326",36893.46385377],["0.00000325",1856135.7257234],["0.00000324",30500],["0.00000323",637915.5601449],["0.00000322",130769.04517739],["0.00000321",645232.18679988],["0.00000320",1634293.9478452],["0.00000319",31529.56751848],["0.00000318",138555.00884435],["0.00000317",1113464.2878347],["0.00000316",276013.49999998],["0.00000315",788968.27148898],["0.00000314",25000],["0.00000313",280488.00958466],["0.00000312",105329.92403145],["0.00000311",334358.45764935],["0.00000310",1421179.8297221],["0.00000309",1022950.5706013],["0.00000308",95061.81560324],["0.00000307",34886.66579372],["0.00000306",25000],["0.00000305",144907.76393442],["0.00000304",25000],["0.00000303",91402.71245924],["0.00000302",25000],["0.00000301",485000],["0.00000300",1130997.9931911],["0.00000299",48.16053511],["0.00000298",6000],["0.00000297",14526.7003367],["0.00000295",23963.23050847],["0.00000294",1820.1691914]],"isFrozen":"0","seq":6482153}

def get_openexchangerates(currency_code,base_code,key)
  #   this is tested as working and so far is seen as the best in the lot  
  # this one when free will only do lookups compared to USD, also limits to 1000 lookup per month so only 1 per hour
  # at $12/month Hourly Updates, 10,000 api request/month
  # at $47/month 30-minute Updates, 100,000 api request/month
  # at $97/month 10-minute Updates, unlimited api request/month + currency conversion requests
  # does lookup more than one currency at a time
  #https://openexchangerates.org/api/latest.json?app_id=xxxxxxx
  # see: https://openexchangerates.org/
  #  example usage:
  #   result = get_openexchangerates("THB","JPY", openexchangerates_key)
  #   puts "rate: " + result["rate"].to_s  ; rate: 2.935490234019467
  #
  # inputs: 
  #  currency_code: the currency code to lookup example THB
  #  base_code: the currency base to use in calculating exchange example USD  or THB  or BTC
  #  key: the api authentication key obtained from https://openexchangerates.org
  #
  # return results:
  #  rate: the calculated rate of exchange
  #  timestamp: time the rate was taken in seconds_since_epoch_integer format (not sure how accurate as the time is the same for all asset currency)
  #  datetime: time in standard human readable format example: 2016-09-15T08:00:14+07:00
  #  base: the base code of the currency being calculated example USD
  #   example if 1 USD is selling for 34.46 THB then rate will return 34.46 for base USD
  #   example#2 if 1 USD is selling for 101.19 KES then rate will return 101.19 for base of USD
  #   example#3 with the same values above  1 THB is selling for 2.901 KES so rate will return 2.901 for base of KES  
  puts "get_openexchangerates started"
  url_start = "https://openexchangerates.org/api/latest.json?app_id="
  url_end = ""
  send = url_start + key
  #puts "sending:  #{send}"
  begin
    #postdata = RestClient.get send , { :Accept => '*/*', 'accept-encoding' => "gzip, deflate", :user_agent => "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:47.0) Gecko/20100101 Firefox/47.0"}
    postdata = RestClient.get send , { :Accept => '*/*', 'accept-encoding' => "gzip, deflate"}
  rescue => e
    puts "fail in get_openexchangerate at RestClient.get  error: #{e}"
    data_out = {}
    data_out["service"] = "openexchangerates.org"
    data_out["status"] = "fail"
    return  data_out
  end
  #puts "postdata: " + postdata
  data = JSON.parse(postdata)
  data_out = {}
  data_out["status"] = "pass"
  if (base_code == "USD")
    #defaults to USD
    data_out["currency_code"] = currency_code
    data_out["base"] = base_code
    data_out["datetime"] = Time.at(data["timestamp"]).to_datetime.to_s
    #date["rate"] = data["rates"][currency_code]
    data_out["rate"] = (data["rates"][currency_code]).to_s
    data_out["ask"] = data_out["rate"]
    data_out["bid"] = data_out["rate"]
    data_out["service"] = "openexchangerates.org"
    puts "data_out: #{data_out}"
    return data_out
  end
  puts "here??"
  usd_base_rate = data["rates"][currency_code]
  base_rate = data["rates"][base_code]
  rate = base_rate / usd_base_rate
  data_out["currency_code"] = currency_code
  #data_out["rate"] = rate.to_s
  #data_out["ask"] = data_out["rate"]
  #data_out["bid"] = data_out["rate"]
  data_out["rate"] = (1.0 / rate.to_f)
  data_out["ask"] = data_out["rate"].to_f
  data_out["bid"] = data_out["rate"].to_f
  data_out["base"] = base_code
  data_out["datetime"] = Time.at(data["timestamp"]).to_datetime.to_s
  data_out["service"] = "openexchangerates.org"
  puts "data_out: #{data_out}"
  return data_out
end



def convert_polo_to_liquid(data_hash_in, min_liquid_shares)
  #this will convert our standard poloniex exchange api format to our
  # shrunken liquid data format:
  # this will return the price of a poloniex exchange book traded asset pair that
  # would be requied to bid or ask if you were to purchase or sell min_liquid_shares of that asset.
  # this only takes a snapshot at the time so may not be what can be achieved at time of order
  # this should at least give you some clue at a glance as to the real price when working with the funds 
  # you plan to be trading.
  # return result example:
  #  {"ask"=>{"price"=>"0.00000383", "volume"=>"578679.19417415", "avg_price"=>"0.00000383", "offer_count"=>3, "total_volume"=>"10683552.18423253", "total_avg_price"=>"0.00000408", "total_offers"=>50}, "bid"=>{"price"=>"0.00000372", "volume"=>"333182.73763676", "avg_price"=>"0.00000372", "offer_count"=>2, "total_volume"=>"18066738.30346057", "total_avg_price"=>"0.00000341", "total_offers"=>50}}
  # 
  # price: is the price you would have to ask or bid to acheive liquidity on your order
  # volume: at this point is only the volume that was acumulated at the point your threshold of min_liquid_shares
  #   was achieved, this number maybe very close or far (much more) than your min_liquid_share if big blocks of shares are 
  #   trading within or near your min number.
  # avg_price: is the actual price you would end up paying (not exact) in your order due to averge price from bottom bid to top
  # offer_count: the number of orders you had to hit before your liquidity was reached
  # total_volume: provides the total number of shares that are now up for sale on ask or bid at a price in the market
  # total_avg_price: this is the price you would ask or bid to buy all present market orders now seen in market (not really useful but?)
  # total_offers: is the total number of orders now seen in bid and ask at this time.  seems to always be 50 so maybe that's just all they show?
  # base: base asset asset_code, asset_issuer contained but only if from stellar format data_hash, this data must be manualy added if from polo
  # counter: counter assets asset_code, asset_issuer info if from stellar format data_hash
  #
  # example currency_code of STR at base_code of BTC with min_liquid_shares set at 300000 shares of STR:
  #  get_poloniex_exchange_liquid("STR","BTC",300000)
  #  
  #
  #puts "convert_polo data_hash_in: #{data_hash_in}" 
  result = data_hash_in
  out_result = {}
  out_result["ask"] = {}
  out_result["bid"] = {}
  if !data_hash_in["base"].nil?
    out_result["base"] = data_hash_in["base"]
    out_result["counter"] = data_hash_in["counter"]
  end
  offer_count = 0
  liquid_mark = false
  total_volume = 0
  total_price = 0
  #puts "min_liquid_shares: #{min_liquid_shares}"
  result["asks"].each{ |row|
    #puts "price: #{row[0]}"
    #puts "volume: #{row[1]}"
    total_volume = total_volume + row[1].to_f
    #puts "total vol: #{total_volume}"
    total_price = total_price + (row[0].to_f * row[1].to_f)
    offer_count = offer_count + 1
    if (total_volume > min_liquid_shares && liquid_mark == false)
      liquid_mark = true
      out_result["ask"]["price"] = format("%.8f",row[0].to_f)
      out_result["ask"]["volume"] = format("%.8f",total_volume)
      out_result["ask"]["avg_price"] = format("%.8f",(total_price / total_volume))  
      out_result["ask"]["offer_count"] = offer_count 
    end
    
  }
  #puts "out_result[ask][price]  #{out_result["ask"]["price"]}"
  out_result["ask"]["total_volume"] = format("%.8f",total_volume)
  if total_volume == 0
    out_result["ask"]["total_avg_price"] = out_result["ask"]["price"]
  else
    out_result["ask"]["total_avg_price"] = format("%.8f",(total_price / total_volume))
  end
  out_result["ask"]["total_offers"] = offer_count
  out_result["rate"] = out_result["ask"]["price"]
  #total_average_ask_price = total_price / total_ask_volume / ask_count 

  offer_count = 0
  liquid_mark = false
  total_volume = 0
  total_price = 0

  result["bids"].each{ |row|
    #puts "price: #{row[0]}"
    #puts "volume: #{row[1]}"
    total_volume = total_volume + row[1].to_f
    #puts "total vol: #{total_ask_volume}"
    total_price = total_price + (row[0].to_f * row[1].to_f)
    offer_count = offer_count + 1
    if (total_volume > min_liquid_shares && liquid_mark == false)
      liquid_mark = true
      out_result["bid"]["price"] = format("%.8f",row[0].to_f)
      out_result["bid"]["volume"] = format("%.8f",total_volume)
      out_result["bid"]["avg_price"] = format("%.8f",(total_price / total_volume))  
      out_result["bid"]["offer_count"] = offer_count 
    end
    
  }

  out_result["bid"]["total_volume"] = format("%.8f",total_volume)
  if total_volume == 0 
    out_result["bid"]["total_avg_price"] = out_result["bid"]["price"]
  else
    out_result["bid"]["total_avg_price"] = format("%.8f",(total_price / total_volume))
  end
  out_result["bid"]["total_offers"] = offer_count
  #puts "out_result: #{out_result}"
  return out_result
end 

def get_poloniex_exchange_liquid(currency_code,base_code,min_liquid)
  #this will return the price of a poloniex exchange traded asset pair that
  # would be requied to bid or ask if you were to purchase or sell min_liquid_shares of that asset.
  # see: convert_polo_to_liquid(data_hash_in, min_liquid_shares) for details
  result = get_poloniex_exchangerate(currency_code,base_code)
  result_lqd = convert_polo_to_liquid(result,min_liquid)
  to_record_feed = {}
  to_record_feed["base"] = base_code
  to_record_feed["currency_code"] = currency_code
  to_record_feed["rate"] = result_lqd["ask"]["price"]
  to_record_feed["ask"] = result_lqd["ask"]["price"]
  to_record_feed["bid"] = result_lqd["bid"]["price"]
  to_record_feed["service"] = "poloniex.com" 
  to_record_feed["datetime"] = Time.now.to_s
  return to_record_feed
end 

def check_float(data)
  return true if Float(data) rescue false
end

    
