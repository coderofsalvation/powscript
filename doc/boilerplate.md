# Full Boilerplate

Here's a full boilerplate with some json action going on:

    require     'json'
    require_cmd 'curl'
    require_env 'PATH'

    usage(app)
      local example_url="https://raw.githubusercontent.com/coderofsalvation/powscript/master/package.json"
      echo "
      $app <json keys...> --url <json file>

      Description:
        obtains and parses the json file given by the url,
      then prints the data corresponding to the received keys.

      Examples:
        $app version         --url '$example_url'
        $app repository type --url '$example_url'
        $app repository url  --url '$example_url'
      "

    myfunc(a b c d @opt)
      echo "$a $b $c $d"
      echo $opt[@]

    run(@keys -- url)
      if empty? url
        echo "Usage: $(usage myapp)" && exit
      data={}
      json=$(curl -s $url)
      json_parse data "$json"
      json_print data $keys[@]

    run $@
