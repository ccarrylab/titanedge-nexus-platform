module github.com/titanedge/nexus/tests

go 1.22

// The static layer (static_test.go) uses only the standard library and runs
// with no further setup. Before running the integration layer
// (-tags=integration), fetch its dependencies once:
//
//   go mod tidy
//
// which will add github.com/gruntwork-io/terratest and
// github.com/stretchr/testify below.
