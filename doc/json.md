# JSON

JSON is a very popular format.
While there are great utilities like `jq`, powscript also supports basic json:

    require     'json'
    require_cmd 'curl'

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

    run(@keys -- url)
      if empty? url
        echo "Usage: $(usage myapp)" && exit
      data={}
      json=$(curl -s $url)
      json_parse data "$json"
      json_print data $keys[@]

    run $@
