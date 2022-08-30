require "uri"
require "net/http"
require "openssl"
require "csv"
require "json"

# put actual order ID's here
order_ids = [
  123456789,
] 

# TODO: use valid values
myshopify_domain_name = "store_name"
$app_secret_token = "secret_token"
$GET = "GET"
$POST = "POST"
headers = ["order_id", "success", "response_code", "error_response"]

def log_response(order_id, response)
  response_code = response.code
  if response_code.to_i >= 400
    success = false
    response_body = response.read_body
  else
    success = true
    begin
      response_body = response.read_body || ""
    rescue
      response_body = "<read_failed>"
    end
  end
  puts "#{order_id}, #{success}, #{response_code}, #{response_body}"
  row = [order_id.to_s, success.to_s, response_code.to_s, response_body.to_s]
end

def api_request(method, url, body = nil)
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(url) if method == $GET
  request = Net::HTTP::Post.new(url) if method == $POST
  request["X-Shopify-Access-Token"] = $app_secret_token
  if body
    request["Content-Type"] = "application/json"
    request.body = body.to_json
  end
  http.request(request)
end

CSV.open("fullsend_responses.csv", "w") do |csv|
  csv << headers
  order_ids.each do |order_id|
    puts "order_id is #{order_id}"
    get_url = URI("https://#{myshopify_domain_name}.myshopify.com/admin/api/2021-07/orders/#{order_id}.json")
    transaction_void_url = URI("https://#{myshopify_domain_name}.myshopify.com/admin/api/2021-07/orders/#{order_id}/transactions.json")
    response = api_request($GET, get_url)
    csv << log_response(order_id, response)

    transaction_void_body = {
      "transaction": {
        "kind": "void",
      },
    }
    response = api_request($POST, transaction_void_url, transaction_void_body)
    csv << log_response(order_id, response)
  end
end
