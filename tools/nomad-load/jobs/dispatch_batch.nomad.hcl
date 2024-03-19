job "dispatch" {
  type = "batch"

  parameterized {}

  group "dispatch" {
    task "dispatch" {
      driver = "mock"
    }
  }
}
