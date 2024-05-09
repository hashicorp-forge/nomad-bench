// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package internal

import (
	"bytes"
	_ "embed"
	"fmt"
	"math/rand/v2"
	"strings"
	"sync"
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
	Driver     string
	Echo       string
	Spread     bool
	Count      int
	Worker     int
	GroupCount int
	Groups     []struct{}
}

type TestJob struct {
	Conf *JobConf

	client  *api.Client
	payload *api.Job
	logger  hclog.Logger
}

// newEcho returns a new echo string with the current time, used to distinguish
// between different job updates
func newEcho() string {
	return fmt.Sprintf("%v hello world!", time.Now().Local().Format("2006-01-02 15:04:05"))
}

func NewJob(jobConf *JobConf, client *api.Client, logger hclog.Logger) *TestJob {
	return &TestJob{jobConf, client, nil, logger}
}

func (j *TestJob) render(worker int) (*api.Job, error) {
	// Parse the job template
	t := template.Must(template.New("jobTpl").Parse(jobTpl))
	j.Conf.Groups = make([]struct{}, j.Conf.GroupCount)
	j.Conf.Echo = newEcho()
	j.Conf.Worker = worker

	buf := new(bytes.Buffer)
	err := t.Execute(buf, j.Conf)
	if err != nil {
		return nil, err
	}

	// Parse the rendered jobspec
	jobspec := buf.String()
	r := strings.NewReader(jobspec)
	return jobspec2.Parse("job.nomad.hcl", r)
}

func (j *TestJob) RegisterBatch() error {
	var err error
	j.payload, err = j.render(0)
	if err != nil {
		return err
	}

	_, _, err = j.client.Jobs().Register(j.payload, nil)
	return err
}

func (j *TestJob) DispatchBatch(wg *sync.WaitGroup, numOfDispatches int, lim *rate.Limiter, rng *rand.Rand) {
	defer wg.Done()

	dispatch := func(i int) {
		r := lim.Reserve()
		time.Sleep(r.Delay())

		if rng != nil {
			time.Sleep(time.Duration(rng.IntN(1000)) * time.Millisecond)
		}

		dispatchResp, _, err := j.client.Jobs().Dispatch(*j.payload.ID, nil, nil, "", nil)
		if err != nil {
			metrics.IncrCounter([]string{"dispatches_error"}, 1)
			j.logger.Error("failed to dispatch job", "error", err)
		}

		metrics.IncrCounter([]string{"dispatches"}, 1)
		j.logger.Info("successfully dispatched job",
			"job_id", *j.payload.ID, "dispatch_job_id", dispatchResp.DispatchedJobID, "dispatch_number", i)
	}

	if numOfDispatches > 0 {
		for i := 0; i < numOfDispatches; i++ {
			dispatch(i)
		}
	} else {
		// 0 is "infinity"
		i := 0
		for {
			dispatch(i)
			i++
		}
	}
	j.logger.Info("sccessfully dispatched jobs", "num_of_dispatches", numOfDispatches)
}

func (j *TestJob) RunService(wg *sync.WaitGroup, worker int, numOfUpdates int, updatesDelay time.Duration) {
	defer wg.Done()

	parsed, err := j.render(worker)
	if err != nil {
		j.logger.Error("failed to render job", "error", err)
		return
	}
	_, _, err = j.client.Jobs().Register(parsed, nil)
	if err != nil {
		metrics.IncrCounter([]string{"registration_error"}, 1)
		j.logger.Error("failed to register job", "error", err)
	}

	metrics.IncrCounter([]string{"registrations"}, 1)
	j.logger.Info("successfully registered job", "job_id", *parsed.ID)

	update := func(i int) {
		time.Sleep(updatesDelay)

		// re-parse the jobspec so that the echo string gets updated
		parsed, err := j.render(worker)
		if err != nil {
			j.logger.Error("failed to render job", "error", err)
			return
		}
		_, _, err = j.client.Jobs().Register(parsed, nil)
		if err != nil {
			metrics.IncrCounter([]string{"job_update_error"}, 1)
			j.logger.Error("failed to update job", "error", err)
		}
		j.logger.Info("successfully updated job", "job_id", *parsed.ID, "update_num", i)
	}

	if numOfUpdates > 0 {
		for i := 0; i < numOfUpdates; i++ {
			update(i)
		}
	} else {
		// 0 is "infinity"
		i := 0
		for {
			update(i)
			i++
		}
	}
}
