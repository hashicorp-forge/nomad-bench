package config

type Log struct {
	Level string
	JSON  bool
}

func DefaultLog() *Log {
	return &Log{
		Level: "debug",
		JSON:  false,
	}
}
