require "test_helper"

class PortfoliosRebalanceTest < ActionDispatch::IntegrationTest
  test "GET / shows form with META and APPL defaults" do
    get root_url

    assert_response :success
    assert_select "form[action='/rebalance']" do
      assert_select "input[name='positions[][ticker]'][value='META']"
      assert_select "input[name='positions[][quantity]'][value='50']"
      assert_select "input[name='positions[][price]'][value='10']"
      assert_select "input[name='positions[][target]'][value='40']"
      assert_select "input[name='positions[][ticker]'][value='APPL']"
      assert_select "input[name='positions[][quantity]'][value='50']"
      assert_select "input[name='positions[][price]'][value='10']"
      assert_select "input[name='positions[][target]'][value='60']"
    end
    refute_match(/\bAAPL\b/, response.body)
  end

  test "POST /rebalance with canonical numbers sells 10 META and buys 10 APPL" do
    post "/rebalance", params: {
      positions: [
        { ticker: "META", quantity: "50", price: "10", target: "40" },
        { ticker: "APPL", quantity: "50", price: "10", target: "60" }
      ]
    }

    assert_response :success
    assert_select ".plan" do
      assert_select ".instruction", text: /sell\s+10(\.0+)?\s+META/i
      assert_select ".instruction", text: /buy\s+10(\.0+)?\s+APPL/i
    end
    assert_select ".holdings" do
      assert_select ".holding", text: /META\s+50(\.0+)?/
      assert_select ".holding", text: /APPL\s+50(\.0+)?/
    end
    refute_match(/\bAAPL\b/, response.body)
  end

  test "POST /rebalance with incomplete weights shows an error and no plan" do
    post "/rebalance", params: {
      positions: [
        { ticker: "META", quantity: "50", price: "10", target: "40" },
        { ticker: "APPL", quantity: "50", price: "10", target: "50" }
      ]
    }

    assert_response :success
    assert_select "p.error", text: /invalid allocation/i
    assert_select ".plan", count: 0
    assert_select ".instruction", count: 0
  end

  test "POST /rebalance with an invalid price shows a price error, not a quantity error" do
    post "/rebalance", params: {
      positions: [
        { ticker: "META", quantity: "50", price: "not-a-number", target: "40" },
        { ticker: "APPL", quantity: "50", price: "10", target: "60" }
      ]
    }

    assert_response :success
    assert_select "p.error", text: /invalid price/i
    assert_select ".plan", count: 0
  end

  test "POST /rebalance with an invalid target shows an allocation error, not a quantity error" do
    post "/rebalance", params: {
      positions: [
        { ticker: "META", quantity: "50", price: "10", target: "not-a-number" },
        { ticker: "APPL", quantity: "50", price: "10", target: "60" }
      ]
    }

    assert_response :success
    assert_select "p.error", text: /invalid allocation/i
    assert_select ".plan", count: 0
  end
end
