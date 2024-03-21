package internal

import _ "embed"

var (
	//go:embed jobs/dispatch_batch.nomad.hcl
	dispatchBatchJob string

	//go:embed jobs/dispatch_batch_spread.nomad.hcl
	dispatchSpreadJob string

	JobMap map[string]string = map[string]string{
		"batch":  dispatchBatchJob,
		"spread": dispatchSpreadJob,
	}
)
