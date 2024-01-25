package write

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"

	"github.com/hashicorp/go-hclog"
)

func JSON(logger hclog.Logger, file string, data []byte) error {

	// Attempt to pretty print the JSON data. If this fails, log the
	// error and use the original "un-pretty", so this error does not
	// mean we lose the data.
	var prettyJSON bytes.Buffer

	if err := json.Indent(&prettyJSON, data, "", "\t"); err != nil {
		logger.Warn("failed to indent JSON data", "error", err)
		prettyJSON.Write(data)
	}

	return WriteBlob(file, prettyJSON.Bytes())
}

func WriteBlob(file string, data []byte) error {

	f, err := os.Create(file)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}

	defer func(f *os.File) { _ = f.Close() }(f)

	if _, err := f.Write(data); err != nil {
		return fmt.Errorf("failed to write data to file: %w", err)
	}

	return nil
}
