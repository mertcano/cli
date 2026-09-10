package daemon

import (
	"testing"

	"github.com/QFEX-org/cli/internal/protocol"
)

func TestModifyOrderWSParamsAlwaysIncludesReduceOnly(t *testing.T) {
	for _, reduceOnly := range []bool{false, true} {
		params := modifyOrderWSParams(protocol.ModifyOrderParams{
			Symbol:     "BTC-USD",
			OrderID:    "8e3d5f0e-6c2a-4a4f-9a4b-1f2c3d4e5f60",
			Side:       "BUY",
			OrderType:  "LIMIT",
			Price:      65000.5,
			Quantity:   1,
			ReduceOnly: reduceOnly,
		})

		got, ok := params["reduce_only"]
		if !ok {
			t.Fatal("reduce_only missing from modify params")
		}
		if got != reduceOnly {
			t.Fatalf("reduce_only = %v, want %v", got, reduceOnly)
		}
	}
}

func TestAddTwapWSParamsIncludesOptionalExecutionControls(t *testing.T) {
	startTime := 1785499200.25
	worstPrice := 65000.5
	params := addTwapWSParams(protocol.AddTwapParams{
		Symbol:            "BTC-USD",
		Side:              "BUY",
		TotalQuantity:     1,
		NumOrders:         2,
		OrderIntervalSecs: 60,
		StartTime:         &startTime,
		WorstPrice:        &worstPrice,
	})

	if got := params["start_time"]; got != startTime {
		t.Fatalf("start_time = %v, want %v", got, startTime)
	}
	if got := params["worst_price"]; got != worstPrice {
		t.Fatalf("worst_price = %v, want %v", got, worstPrice)
	}
}

func TestAddTwapWSParamsOmitsOptionalExecutionControls(t *testing.T) {
	params := addTwapWSParams(protocol.AddTwapParams{})

	if _, ok := params["start_time"]; ok {
		t.Fatal("start_time unexpectedly present")
	}
	if _, ok := params["worst_price"]; ok {
		t.Fatal("worst_price unexpectedly present")
	}
}
