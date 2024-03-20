package internal

import _ "embed"

//go:embed jobs/dispatch_batch.nomad.hcl
var DispatchBatchJob string
