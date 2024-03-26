package internal

import (
	"bytes"
	"context"
	_ "embed"
	"fmt"
	"math/rand/v2"
	"strings"
	"text/template"
	"time"

	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/go-metrics"
	"github.com/hashicorp/nomad/api"
	"github.com/hashicorp/nomad/jobspec2"
	"golang.org/x/time/rate"
)

//go:embed job.nomad.hcl.tpl
var jobTpl string

type JobConf struct {
	JobType    string
	Spread     bool
	Count      int
	GroupCount int
	Groups     []struct{}
}

type TestJob struct {
	Conf *JobConf

	client  *api.Client
	payload *api.Job
	logger  hclog.Logger
}

func NewJob(jobConf *JobConf, client *api.Client, logger hclog.Logger) (*TestJob, error) {
	// Parse the job template
	t := template.Must(template.New("jobTpl").Parse(jobTpl))
	jobConf.Groups = make([]struct{}, jobConf.GroupCount)

	buf := new(bytes.Buffer)
	err := t.Execute(buf, jobConf)
	if err != nil {
		return nil, err
	}

	// Parse the rendered jobspec
	jobspec := buf.String()
	r := strings.NewReader(jobspec)
	parsed, err := jobspec2.Parse("job.nomad.hcl", r)
	if err != nil {
		return nil, err
	}

	return &TestJob{jobConf, client, parsed, logger}, nil
}

func (j *TestJob) RegisterBatch(jobspec string) error {
	_, _, err := j.client.Jobs().Register(j.payload, nil)
	if err != nil {
		return err
	}

	return nil
}

func (j *TestJob) Run(ctx context.Context, lim *rate.Limiter, rng *rand.Rand, allocs chan *api.Allocation) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		default:
		}

		r := lim.Reserve()
		if !r.OK() {
			continue
		}
		time.Sleep(r.Delay())

		if rng != nil {
			time.Sleep(time.Duration(rng.IntN(1000)) * time.Millisecond)
		}

		switch j.Conf.JobType {
		case "batch":
			_, _, err := j.client.Jobs().Dispatch(*j.payload.ID, nil, nil, "", nil)
			if err != nil {
				metrics.IncrCounter([]string{"dispatches_error"}, 1)
				j.logger.Error("failed to dispatch job", "error", err)
				continue
			}
			metrics.IncrCounter([]string{"dispatches"}, 1)
		case "service":
			_, _, err := j.client.Jobs().Register(*&j.payload, nil)
			if err != nil {
				metrics.IncrCounter([]string{"dispatches_error"}, 1)
				j.logger.Error("failed to dispatch job", "error", err)
				continue
			}
			metrics.IncrCounter([]string{"dispatches"}, 1)
		default:
			return fmt.Errorf("job type %s not supported", j.Conf.JobType)
		}
	}
}
