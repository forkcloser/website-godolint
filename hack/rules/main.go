// The rules the pinned godolint carries, one per line: code, severity,
// message, tab-separated, in code order. The rules test diffs this against
// the rules page; it runs inside limen's tools module (go -C .limen/tools
// run), so the module is the one .limen/tools/go.mod pins.
package main

import (
	"fmt"
	"os"

	"github.com/forkcloser/godolint/sdk"
)

func main() {
	for _, r := range sdk.Rules() {
		if _, err := fmt.Fprintf(os.Stdout, "%s\t%s\t%s\n", r.Code, r.Severity, r.Message); err != nil {
			fmt.Fprintln(os.Stderr, "rules:", err)
			os.Exit(1)
		}
	}
}
