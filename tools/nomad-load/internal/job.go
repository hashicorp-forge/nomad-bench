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
	if err != nil {
		return err
	}

	return nil
}

func (j *TestJob) Run(ctx context.Context, lim *rate.Limiter, rng *rand.Rand, worker int, update bool, jobType string) error {
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

		parsed, err := j.render(worker)
		if err != nil {
			return err
		}

		switch jobType {
		case JobTypeBatch:
			_, _, err := j.client.Jobs().Dispatch(*j.payload.ID, nil, nil, "", nil)
			if err != nil {
				metrics.IncrCounter([]string{"dispatches_error"}, 1)
				j.logger.Error("failed to dispatch job", "error", err)
				continue
			}
			metrics.IncrCounter([]string{"dispatches"}, 1)
		case JobTypeService:
			_, _, err = j.client.Jobs().Register(parsed, nil)
			if err != nil {
				metrics.IncrCounter([]string{"registration_error"}, 1)
				j.logger.Error("failed to register job", "error", err)
				continue
			}
			metrics.IncrCounter([]string{"registrations"}, 1)
		default:
			j.logger.Error("incorrect job type", "type", jobType)
		}
	}
}
