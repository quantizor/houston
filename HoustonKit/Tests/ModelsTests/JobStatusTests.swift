import Testing
@testable import Models

@Suite("JobStatus Tests")
struct JobStatusTests {
    @Test("Running status properties")
    func runningStatus() {
        let status = JobStatus.running(pid: 1234)
        #expect(status.isRunning == true)
        #expect(status.isLoaded == true)
        #expect(status.statusColor == "green")
        #expect(status.statusDescription == "Running (PID 1234)")
    }

    @Test("Loaded status with exit code")
    func loadedWithExitCode() {
        let status = JobStatus.loaded(lastExitCode: 1)
        #expect(status.isRunning == false)
        #expect(status.isLoaded == true)
        #expect(status.statusColor == "yellow")
        #expect(status.statusDescription == "Loaded (exit code 1)")
    }

    @Test("Loaded status without exit code")
    func loadedNoExitCode() {
        let status = JobStatus.loaded(lastExitCode: nil)
        #expect(status.statusDescription == "Loaded")
    }

    @Test("Unloaded status properties")
    func unloadedStatus() {
        let status = JobStatus.unloaded
        #expect(status.isRunning == false)
        #expect(status.isLoaded == false)
        #expect(status.statusColor == "gray")
        #expect(status.statusDescription == "Not Loaded")
    }

    @Test("Error status properties")
    func errorStatus() {
        let status = JobStatus.error("something went wrong")
        #expect(status.isRunning == false)
        #expect(status.isLoaded == false)
        #expect(status.statusColor == "red")
        #expect(status.statusDescription == "Error: something went wrong")
    }

    @Test("Equatable conformance")
    func equatable() {
        #expect(JobStatus.running(pid: 42) == JobStatus.running(pid: 42))
        #expect(JobStatus.running(pid: 42) != JobStatus.running(pid: 43))
        #expect(JobStatus.unloaded == JobStatus.unloaded)
        #expect(JobStatus.unloaded != JobStatus.error("x"))
    }
}
