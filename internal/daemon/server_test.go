package daemon

import (
	"testing"

	"github.com/QFEX-org/cli/internal/protocol"
)

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
