import Testing
import Foundation
@testable import Models

@Suite("LaunchdJob Tests")
struct LaunchdJobTests {
    @Test("Init sets id equal to label")
    func initSetsIdEqualToLabel() {
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/com.example.test.plist")
        )
        #expect(job.id == "com.example.test")
        #expect(job.label == "com.example.test")
    }

    @Test("Default status is unloaded")
    func defaultStatusIsUnloaded() {
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.status == .unloaded)
        #expect(job.isEnabled == true)
    }

    @Test("Display name returns last label component")
    func displayNameReturnsLastComponent() {
        let job = LaunchdJob(
            label: "com.example.myagent",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.displayName == "myagent")
    }

    @Test("Display name for single-component label")
    func displayNameSingleComponent() {
        let job = LaunchdJob(
            label: "myagent",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.displayName == "myagent")
    }

    @Test("Executable path prefers program over programArguments")
    func executablePathPrefersProgram() {
        var job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        job.program = "/usr/bin/env"
        job.programArguments = ["/bin/sh", "-c", "echo hello"]
        #expect(job.executablePath == "/usr/bin/env")
    }

    @Test("Executable path falls back to programArguments first element")
    func executablePathFallback() {
        var job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        job.programArguments = ["/bin/sh", "-c", "echo hello"]
        #expect(job.executablePath == "/bin/sh")
    }

    @Test("Executable path is nil when no program or arguments")
    func executablePathNil() {
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.executablePath == nil)
    }

    @Test("ProcessType promoted field")
    func processTypeField() {
        var job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.processType == nil)
        job.processType = "Background"
        #expect(job.processType == "Background")
    }

    @Test("Vendor prefix for three-component label")
    func vendorThreeComponents() {
        let job = LaunchdJob(
            label: "com.apple.Spotlight",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.vendor == "com.apple")
    }

    @Test("Vendor prefix for two-component label returns full label")
    func vendorTwoComponents() {
        let job = LaunchdJob(
            label: "com.example",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.vendor == "com.example")
    }

    @Test("Vendor prefix for single-component label returns full label")
    func vendorSingleComponent() {
        let job = LaunchdJob(
            label: "myagent",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.vendor == "myagent")
    }

    @Test("Vendor prefix for four-component label")
    func vendorFourComponents() {
        let job = LaunchdJob(
            label: "com.apple.audio.coreaudiod",
            domain: .systemDaemon,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.vendor == "com.apple")
    }

    @Test("Display name for two-component label")
    func displayNameTwoComponent() {
        let job = LaunchdJob(
            label: "com.myagent",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.displayName == "myagent")
    }

    @Test("Executable path is nil with empty programArguments")
    func executablePathEmptyArgs() {
        var job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        job.programArguments = []
        #expect(job.executablePath == nil)
    }

    @Test("All promoted fields default to nil")
    func promotedFieldsDefaultNil() {
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.programArguments == nil)
        #expect(job.program == nil)
        #expect(job.runAtLoad == nil)
        #expect(job.keepAlive == nil)
        #expect(job.startInterval == nil)
        #expect(job.startCalendarInterval == nil)
        #expect(job.standardOutPath == nil)
        #expect(job.standardErrorPath == nil)
        #expect(job.workingDirectory == nil)
        #expect(job.environmentVariables == nil)
        #expect(job.userName == nil)
        #expect(job.groupName == nil)
        #expect(job.disabled == nil)
        #expect(job.processType == nil)
    }

    @Test("Init with custom status and isEnabled")
    func initWithCustomStatusAndEnabled() {
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .globalDaemon,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist"),
            status: .running(pid: 1234),
            isEnabled: false
        )
        #expect(job.status == .running(pid: 1234))
        #expect(job.isEnabled == false)
        #expect(job.domain == .globalDaemon)
    }

    @Test("Setting and reading environmentVariables")
    func environmentVariables() {
        var job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        job.environmentVariables = ["PATH": "/usr/bin", "HOME": "/Users/test"]
        #expect(job.environmentVariables?["PATH"] == "/usr/bin")
        #expect(job.environmentVariables?["HOME"] == "/Users/test")
    }
}

// MARK: - JobDomainType Tests

@Suite("JobDomainType Tests")
struct JobDomainTypeTests {
    @Test("System domains are read-only")
    func systemDomainsReadOnly() {
        #expect(JobDomainType.systemAgent.isReadOnly)
        #expect(JobDomainType.systemDaemon.isReadOnly)
        #expect(JobDomainType.launchAngel.isReadOnly)
    }

    @Test("User and global domains are not read-only")
    func editableDomainsNotReadOnly() {
        #expect(!JobDomainType.userAgent.isReadOnly)
        #expect(!JobDomainType.globalAgent.isReadOnly)
        #expect(!JobDomainType.globalDaemon.isReadOnly)
    }

    @Test("System domain directories are correct")
    func systemDomainDirectories() {
        #expect(JobDomainType.systemAgent.directory == "/System/Library/LaunchAgents")
        #expect(JobDomainType.systemDaemon.directory == "/System/Library/LaunchDaemons")
        #expect(JobDomainType.launchAngel.directory == "/System/Library/LaunchAngels")
    }

    @Test("System domains require privilege")
    func systemDomainsRequirePrivilege() {
        #expect(JobDomainType.systemAgent.requiresPrivilege)
        #expect(JobDomainType.systemDaemon.requiresPrivilege)
        #expect(JobDomainType.launchAngel.requiresPrivilege)
    }

    @Test("System domains use correct launchctl domains")
    func systemDomainsLaunchctlDomain() {
        // System agents run in the user's GUI session (like user agents)
        #expect(JobDomainType.systemAgent.launchctlDomain.hasPrefix("gui/"))
        // System daemons and Launch Angels run in the system domain
        #expect(JobDomainType.systemDaemon.launchctlDomain == "system")
        #expect(JobDomainType.launchAngel.launchctlDomain == "system")
    }

    @Test("Display names are set")
    func displayNames() {
        #expect(JobDomainType.systemAgent.displayName == "System Agents")
        #expect(JobDomainType.systemDaemon.displayName == "System Daemons")
        #expect(JobDomainType.launchAngel.displayName == "Launch Angels")
    }

    @Test("All cases includes all 6 domains")
    func allCasesCount() {
        #expect(JobDomainType.allCases.count == 6)
    }

    @Test("User agent does not require privilege")
    func userAgentNoPrivilege() {
        #expect(!JobDomainType.userAgent.requiresPrivilege)
    }

    @Test("Global agents and daemons require privilege")
    func globalDomainsRequirePrivilege() {
        #expect(JobDomainType.globalAgent.requiresPrivilege)
        #expect(JobDomainType.globalDaemon.requiresPrivilege)
    }

    @Test("User agent directory contains LaunchAgents")
    func userAgentDirectory() {
        #expect(JobDomainType.userAgent.directory.hasSuffix("/Library/LaunchAgents"))
    }

    @Test("Global domain directories are correct")
    func globalDomainDirectories() {
        #expect(JobDomainType.globalAgent.directory == "/Library/LaunchAgents")
        #expect(JobDomainType.globalDaemon.directory == "/Library/LaunchDaemons")
    }

    @Test("User agent launchctl domain uses gui prefix")
    func userAgentLaunchctlDomain() {
        #expect(JobDomainType.userAgent.launchctlDomain.hasPrefix("gui/"))
    }

    @Test("Global agent uses gui domain, global daemon uses system domain")
    func globalAgentLaunchctlDomain() {
        // Global agents from /Library/LaunchAgents run in the user's GUI session
        #expect(JobDomainType.globalAgent.launchctlDomain.hasPrefix("gui/"))
        #expect(JobDomainType.globalDaemon.launchctlDomain == "system")
    }

    @Test("Display names for user and global domains")
    func userGlobalDisplayNames() {
        #expect(JobDomainType.userAgent.displayName == "User Agents")
        #expect(JobDomainType.globalAgent.displayName == "Global Agents")
        #expect(JobDomainType.globalDaemon.displayName == "Global Daemons")
    }

    @Test("Id matches rawValue")
    func idMatchesRawValue() {
        for domain in JobDomainType.allCases {
            #expect(domain.id == domain.rawValue)
        }
    }
}

// MARK: - JobStatus Sort Priority Tests (extends existing JobStatusTests)

@Suite("JobStatus Sort Priority Tests")
struct JobStatusSortPriorityTests {
    @Test("Sort priority ordering: running < error < loaded < unloaded")
    func sortPriority() {
        #expect(JobStatus.running(pid: 1).sortPriority < JobStatus.error("x").sortPriority)
        #expect(JobStatus.error("x").sortPriority < JobStatus.loaded(lastExitCode: 0).sortPriority)
        #expect(JobStatus.loaded(lastExitCode: 0).sortPriority < JobStatus.unloaded.sortPriority)
    }
}

// MARK: - ServiceInfo Tests

@Suite("ServiceInfo Tests")
struct ServiceInfoTests {
    @Test("ServiceInfo defaults to nil fields")
    func defaultNilFields() {
        let info = ServiceInfo()
        #expect(info.runs == nil)
        #expect(info.lastExitReason == nil)
        #expect(info.spawnType == nil)
        #expect(info.activeCount == nil)
        #expect(info.forks == nil)
        #expect(info.execs == nil)
        #expect(info.processStartTime == nil)
    }

    @Test("ServiceInfo Equatable conformance")
    func equatable() {
        let a = ServiceInfo()
        let b = ServiceInfo()
        #expect(a == b)
    }
}

// MARK: - ExitCodeInfo Tests

@Suite("ExitCodeInfo Tests")
struct ExitCodeInfoTests {
    @Test("Known sysexits codes have explanations")
    func sysexitCodes() {
        #expect(ExitCodeInfo.explanation(for: 0) == "Exited normally")
        #expect(ExitCodeInfo.explanation(for: 64)?.contains("usage") == true)
        #expect(ExitCodeInfo.explanation(for: 77)?.contains("Permission") == true)
        #expect(ExitCodeInfo.explanation(for: 78)?.contains("Configuration") == true)
        #expect(ExitCodeInfo.explanation(for: 127)?.contains("not found") == true)
    }

    @Test("Signal-based exit codes (128+N)")
    func signalCodes() {
        #expect(ExitCodeInfo.explanation(for: 137)?.contains("SIGKILL") == true)  // 128+9
        #expect(ExitCodeInfo.explanation(for: 139)?.contains("SIGSEGV") == true)  // 128+11
        #expect(ExitCodeInfo.explanation(for: 143)?.contains("SIGTERM") == true)  // 128+15
    }

    @Test("Unknown exit code returns nil")
    func unknownCode() {
        #expect(ExitCodeInfo.explanation(for: 42) == nil)
        #expect(ExitCodeInfo.explanation(for: 255) == nil)
    }
}

// MARK: - JobDiagnostic Tests

@Suite("JobDiagnostic Tests")
struct JobDiagnosticTests {
    private func makeJob(
        status: JobStatus = .unloaded,
        isEnabled: Bool = true,
        runAtLoad: Bool? = nil,
        startInterval: Int? = nil
    ) -> LaunchdJob {
        var job = LaunchdJob(
            label: "com.test.diagnostic",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist"),
            status: status,
            isEnabled: isEnabled
        )
        job.runAtLoad = runAtLoad
        job.startInterval = startInterval
        return job
    }

    @Test("Running job with no issues returns nil")
    func runningHealthy() {
        let job = makeJob(status: .running(pid: 123))
        let result = JobDiagnostic.diagnose(job: job, serviceInfo: nil, analysisResults: [])
        #expect(result == nil)
    }

    @Test("Running job with analysis errors reports them")
    func runningWithErrors() {
        let job = makeJob(status: .running(pid: 123))
        let error = AnalysisResult(severity: .error, title: "Bad config", description: "Bad")
        let result = JobDiagnostic.diagnose(job: job, serviceInfo: nil, analysisResults: [error])
        #expect(result?.contains("1") == true)
        #expect(result?.contains("issue") == true)
    }

    @Test("Disabled job explains disablement")
    func disabledJob() {
        let job = makeJob(isEnabled: false)
        let result = JobDiagnostic.diagnose(job: job, serviceInfo: nil, analysisResults: [])
        #expect(result?.contains("disabled") == true)
    }

    @Test("Non-zero exit code includes explanation")
    func nonZeroExit() {
        let job = makeJob(status: .loaded(lastExitCode: 78))
        let result = JobDiagnostic.diagnose(job: job, serviceInfo: nil, analysisResults: [])
        #expect(result?.contains("78") == true)
        #expect(result?.contains("Configuration") == true)
    }

    @Test("Unloaded job with no triggers explains situation")
    func unloadedNoTrigger() {
        let job = makeJob(status: .unloaded)
        let result = JobDiagnostic.diagnose(job: job, serviceInfo: nil, analysisResults: [])
        #expect(result?.contains("no automatic trigger") == true)
    }

    @Test("Unloaded job with RunAtLoad has different message")
    func unloadedWithRunAtLoad() {
        let job = makeJob(status: .unloaded, runAtLoad: true)
        let result = JobDiagnostic.diagnose(job: job, serviceInfo: nil, analysisResults: [])
        #expect(result?.contains("not loaded") == true)
        #expect(result?.contains("no automatic trigger") != true)
    }

    @Test("Loaded with exit 0 and schedule returns waiting message with schedule")
    func loadedWaiting() {
        let job = makeJob(status: .loaded(lastExitCode: 0), startInterval: 300)
        let result = JobDiagnostic.diagnose(job: job, serviceInfo: nil, analysisResults: [])
        #expect(result?.contains("Waiting") == true || result?.contains("waiting") == true)
        #expect(result?.contains("5 minutes") == true)
    }

    @Test("Loaded with exit 0 and no schedule returns nil")
    func loadedHealthy() {
        let job = makeJob(status: .loaded(lastExitCode: 0))
        let result = JobDiagnostic.diagnose(job: job, serviceInfo: nil, analysisResults: [])
        #expect(result == nil)
    }
}

// MARK: - ScheduleInfo Tests

@Suite("ScheduleInfo Tests")
struct ScheduleInfoTests {
    @Test("Interval description for seconds")
    func intervalSeconds() {
        #expect(ScheduleInfo.description(startInterval: 30, startCalendarInterval: nil) == "Every 30 seconds")
    }

    @Test("Interval description for minutes")
    func intervalMinutes() {
        #expect(ScheduleInfo.description(startInterval: 300, startCalendarInterval: nil) == "Every 5 minutes")
        #expect(ScheduleInfo.description(startInterval: 60, startCalendarInterval: nil) == "Every 1 minute")
    }

    @Test("Interval description for hours")
    func intervalHours() {
        #expect(ScheduleInfo.description(startInterval: 3600, startCalendarInterval: nil) == "Every 1 hour")
        #expect(ScheduleInfo.description(startInterval: 7200, startCalendarInterval: nil) == "Every 2 hours")
    }

    @Test("Interval description for days")
    func intervalDays() {
        #expect(ScheduleInfo.description(startInterval: 86400, startCalendarInterval: nil) == "Every 1 day")
    }

    @Test("Calendar description: daily at specific time")
    func calendarDaily() {
        let desc = ScheduleInfo.description(startInterval: nil, startCalendarInterval: ["Hour": 14, "Minute": 30])
        #expect(desc == "Daily at 2:30 PM")
    }

    @Test("Calendar description: weekly on specific day")
    func calendarWeekly() {
        let desc = ScheduleInfo.description(startInterval: nil, startCalendarInterval: ["Hour": 3, "Minute": 0, "Weekday": 1])
        // Weekday 1 = Monday in launchd (Sunday=0)
        #expect(desc?.contains("Monday") == true || desc?.contains("Sunday") == true)
        #expect(desc?.contains("3:00 AM") == true)
    }

    @Test("Calendar description: hourly at specific minute")
    func calendarHourly() {
        let desc = ScheduleInfo.description(startInterval: nil, startCalendarInterval: ["Minute": 15])
        #expect(desc == "Every hour at :15")
    }

    @Test("Calendar description: monthly")
    func calendarMonthly() {
        let desc = ScheduleInfo.description(startInterval: nil, startCalendarInterval: ["Day": 1, "Hour": 0, "Minute": 0])
        #expect(desc?.contains("Monthly") == true)
        #expect(desc?.contains("day 1") == true)
    }

    @Test("No schedule returns nil")
    func noSchedule() {
        #expect(ScheduleInfo.description(startInterval: nil, startCalendarInterval: nil) == nil)
        #expect(ScheduleInfo.nextFireDate(startInterval: nil, startCalendarInterval: nil) == nil)
        #expect(ScheduleInfo.nextRunString(startInterval: nil, startCalendarInterval: nil) == nil)
    }

    @Test("Next fire date for interval is in the future")
    func nextFireInterval() {
        let now = Date()
        let next = ScheduleInfo.nextFireDate(startInterval: 300, startCalendarInterval: nil, from: now)
        #expect(next != nil)
        #expect(next! > now)
        #expect(abs(next!.timeIntervalSince(now) - 300) < 1)
    }

    @Test("Next fire date for calendar is in the future")
    func nextFireCalendar() {
        let now = Date()
        let next = ScheduleInfo.nextFireDate(startInterval: nil, startCalendarInterval: ["Hour": 12, "Minute": 0], from: now)
        #expect(next != nil)
        #expect(next! > now)
    }

    @Test("Next run string for today says 'next at'")
    func nextRunToday() {
        // Use a time 1 minute from now to ensure it's today
        let now = Date()
        let str = ScheduleInfo.nextRunString(startInterval: 60, startCalendarInterval: nil, from: now)
        #expect(str?.contains("next at") == true)
    }

    @Test("Zero interval returns nil")
    func zeroInterval() {
        #expect(ScheduleInfo.description(startInterval: 0, startCalendarInterval: nil) == nil)
        #expect(ScheduleInfo.nextFireDate(startInterval: 0, startCalendarInterval: nil) == nil)
    }
}

// MARK: - AppleServiceInfo Tests

@Suite("AppleServiceInfo Tests")
struct AppleServiceInfoTests {
    @Test("Known services return descriptions")
    func knownServices() {
        #expect(AppleServiceInfo.description(for: "com.apple.metadata.mds") != nil)
        #expect(AppleServiceInfo.description(for: "com.apple.securityd") != nil)
        #expect(AppleServiceInfo.description(for: "com.apple.WindowServer") != nil)
        #expect(AppleServiceInfo.description(for: "com.apple.logd") != nil)
    }

    @Test("Unknown services return nil")
    func unknownServices() {
        #expect(AppleServiceInfo.description(for: "com.example.myapp") == nil)
        #expect(AppleServiceInfo.description(for: "com.apple.nonexistent.thing") == nil)
        #expect(AppleServiceInfo.description(for: "") == nil)
    }

    @Test("Descriptions are non-empty and concise")
    func descriptionQuality() {
        if let desc = AppleServiceInfo.description(for: "com.apple.metadata.mds") {
            #expect(!desc.isEmpty)
            #expect(desc.count < 100) // concise
            #expect(desc.lowercased().contains("spotlight") || desc.lowercased().contains("index"))
        }
    }

    @Test("User agent labels work too")
    func userAgentLabels() {
        #expect(AppleServiceInfo.description(for: "com.apple.cfprefsd.xpc.agent") != nil)
        #expect(AppleServiceInfo.description(for: "com.apple.usernotificationsd") != nil)
    }
}
