using Sockets, HTTP, JSON, Dates

function refresh_oauth_token(client_id, client_secret, refresh_token; retries=3, backoff=1)
  headers = Dict("Content-Type" => "application/x-www-form-urlencoded")
  body = "client_id=$client_id&client_secret=$client_secret&refresh_token=$refresh_token&grant_type=refresh_token"

  for attempt in 1:retries
    try
      response = HTTP.post(TOKEN_URL, headers, body)
      response_body = String(response.body)
      if response.status == 200
        token_info = JSON.parse(response_body)
        return token_info
      else
        @error "Failed to refresh access token: $(response.status) - $(String(response.body))"
      end
    catch e
      if attempt == retries
        rethrow(e)
      else
        @warn "Attempt $attempt failed. Retrying in $backoff seconds..." 
        sleep(backoff)
        backoff *= 2
      end
    end
  end
end

function test_access_token(access_token)
  try
    test_url = TEST_TOKEN_URL * access_token
    response = HTTP.get(test_url)
    return response.status == 200
  catch
    return false
  end
end

function save_token_data(token_file, token_data, client_id, client_secret)
  current_datetime = now()
  expiry = current_datetime + Dates.Second(token_data["expires_in"])
  token_data["expiry"] = expiry
  token_data["client_id"] = client_id
  token_data["client_secret"] = client_secret
  write(token_file, JSON.json(token_data))
end

function get_access_token_from_file(client_id, client_secret, token_file)
  token_data = JSON.parse(read(token_file, String))

  if haskey(token_data, "access_token")
    access_token = token_data["access_token"]
    refresh_token = token_data["refresh_token"]

    if test_access_token(access_token)
      return access_token
    else
      @info "Access token expired or invalid. Refreshing token..."
      new_token_data = refresh_oauth_token(client_id, client_secret, refresh_token)
      new_token_data["refresh_token"] = refresh_token
      save_token_data(token_file, new_token_data, client_id, client_secret)
      return new_token_data["access_token"]
    end
  else
    error("No access token found in token.json")
  end
end

function get_oauth_token(client_id, client_secret, token_file)
  @info "Go to the following URL and authorize the application: $AUTH_URL?client_id=$client_id&redirect_uri=$REDIRECT_URI&response_type=code&scope=$SCOPE"

  server = Sockets.listen(ip"127.0.0.1", 8080)

  sock = Sockets.accept(server)
  request = String(readavailable(sock))

  code = ""
  for line in split(request, "\r\n")
    if startswith(line, "GET /?")
      query_params = split(line[7:end], "&")
      for param in query_params
        key_value = split(param, "=")
        if key_value[1] == "code"
          code = key_value[2]
        end
      end
    end
  end

  HTTP.Response(HTTP.StatusCode(200), "Authorization successful. You can close this window now.") |> HTTP.send(sock)
  flush(sock)
  close(sock)
  close(server)

  headers = Dict("Content-Type" => "application/x-www-form-urlencoded")
  body = "code=$code&client_id=$client_id&client_secret=$client_secret&redirect_uri=$REDIRECT_URI&grant_type=authorization_code"
  response = HTTP.post(TOKEN_URL, headers, body)

  response_body = String(response.body)
  if response.status == 200
    token_info = JSON.parse(response_body)
    save_token_data(token_file, token_info, client_id, client_secret)
    return token_info["access_token"]
  else
    error("Failed to get access token: $(response.status)")
  end
end
