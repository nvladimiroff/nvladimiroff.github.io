---
layout: post
title: Mocking HTTP APIs with Sinatra
---

[WebMock](https://github.com/bblimke/webmock) is a great library! Being able to transparently replace all HTTP requests is a great tool for writing effective tests. But trying to write more complicated mocks and stubs can sometimes be a little awkward.

## The basics

For example, imagine you had a service you were trying to write tests for that depends on an Orders API, and you'd like to use to WebMock to mock that API out during testing. A first pass could look something like this:
```ruby
# test_helper.rb
def setup
  order_1 = {
    item: 'cool new book',
    count: 10000
  }
  stub_request(:get, 'https://orders.api.example.com/orders/1').
    to_return_json(body: order_1)

  stub_request(:get, 'https://orders.api.example.com/orders').
    to_return_json(body: {
      orders: [order1]
    })
end
```

That works, but what if you needed to support more orders? You could add more calls to `stub_request`, but that could get awkward at larger scales. What if you needed to support a post endpoint that created orders? There are some options here, but many of them are awkward and require you to reimplement some basic HTTP request handling. Instead, we're going to look at `to_rack`.

## The magic of to_rack

`to_rack` is a method WebMock gives us that lets us stub out a request with a _Rack application_. Rack is Ruby's standard for HTTP servers, so anything that looks like an HTTP service can be used here. While we could use Rails, we really just want something lightweight, and luckily the Ruby ecosystem has the perfect option: [Sinatra](https://github.com/sinatra/sinatra)!

Our fake Sinatra-fueled Orders API will look like this:
```ruby
# fake_orders_api.rb
class FakeOrdersApi < Sinatra::Base

  mattr_accessor(:orders, default: {})
  before do
    content_type(:json)
  end

  get('/orders') do
    {
      orders: orders
    }.to_json
  end

  get('/order/:id') do
    orders[params['id']].to_json
  end

end
```

That `mattr_accessor(:orders, default: {})` line sets up a hash that we can use like a database for our Orders API. In our test helper, we can easily add something to it like this:
```ruby
MockOrdersApi.orders[1] = {
  item: 'cool new book',
  count: 10000
}
```
and then connect our Sinatra app to WebMock with this:
```ruby
stub_request(:any, /https:\/\/orders.api.example.com\/.*/).to_rack(FakeOrdersApi)
```
And that's it! Now any requests made in your tests will go through `FakeOrdersApi`, and if needed to do something more complicated like adding a POST endpoint, it's straightforward:
```ruby
post('/orders') do
  orders[params['id']] = {
    item: params['item'],
    count: params['count']
  }
end
```
