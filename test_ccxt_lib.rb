# simple test examples of ccxt_lib.rb functions
# to start app for test: bundler exec ruby ./test_ccxt_lib.rb

 require './ccxt_lib.rb' 
   # standard ccxt server
   $ccxt_config["url"] =  "http://localhost:3000"
   # ruby ccxt-server
   #$ccxt_config["url"] = "http://localhost:8080"
   currency_code = "USD"
   base_code = "XLM" 

   exchanges = [["kraken",66],["poloniex",33]] 
   #mode = "fallback"
   mode = "weighted_averge"
  
   #puts "get_any: #{ get_any_exchangerate(currency_code, base_code,params)}"
   #puts "get_crypto: #{get_crypto_exchangerate(currency_code,base_code)}"
   puts ""
   #puts "get_kraken: #{get_kraken_exchangerate(currency_code, base_code)}"
   #result_kraken = get_kraken_exchangerate(currency_code, base_code)
   #result_crypto = get_crypto_exchangerate(currency_code,base_code)
   $ccxt_config["exchange"] = "kraken"
   get_ccxt_exchangerate(currency_code, base_code)
   # to see all exchanges supported by ccxt: curl http://localhost:3000/exchanges
   $ccxt_config["exchange"] = "poloniex"
   get_ccxt_exchangerate(currency_code, base_code)

   $ccxt_config["url"] = "http://localhost:8080"
   $ccxt_config["exchange"] = "custom"
   get_ccxt_exchangerate(currency_code, base_code)

   # note when we reverse base and currency in this case the standard ccxt values will still be reversed 1/x
   # only the rate value is fixed in this case.  I assume when others that write code to use this lib will deal with 
   # assets that can't be reversed on the exchange side in there own way if they need to make use of ask and bid values.
   # my returned rate is the value that is center of ask and bid and fixed when unsupported reversal is used in my use cases.
   currency_code = "XLM"
   base_code = "USD"  
   $ccxt_config["url"] =  "http://localhost:3000"
   $ccxt_config["exchange"] = "kraken"
   get_ccxt_exchangerate(currency_code, base_code)
   # to see all exchanges supported by ccxt: curl http://localhost:3000/exchanges
   $ccxt_config["exchange"] = "poloniex"
   result = get_ccxt_exchangerate(currency_code, base_code)
   puts "get_ccxt_exchange poloniex: #{result}"
   puts "get_any_exchange: #{get_any_exchangerate(currency_code, base_code)}"

   $ccxt_config["url"] = "http://localhost:8080"
   $ccxt_config["exchange"] = "custom"
   get_ccxt_exchangerate(currency_code, base_code)

   puts "get_averge_feed: #{get_averge_feed(currency_code,base_code,exchanges,mode)}"
