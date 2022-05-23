//
//  HostStatusDetail.swift
//  SwiftTermApp
//
// WARNING: because "onChange" does not work, and I resorted to a "task" to kill the ongoing Top
// this causes navigation links to kill the task, and thus pop back up.
//
//  Created by Miguel de Icaza on 4/27/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation
import SwiftUI

struct HostStatusDetail: View {
    @ObservedObject var top: Top
    @Binding var historicLoad: [Float]
    @State var showAllProcesses = false
    static let gaugeSize = 60.0
    
    struct LabeledPercentView: View {
        var label: String
        var color: Color
        var text: Text
        var body: some View {
            HStack {
                Rectangle ()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text (label)
                    .allowsTightening(true)
                    .lineLimit(1)
                Spacer ()
                text
            }
        }
    }

    struct DebugView: View {
        @ObservedObject var top: Top
    
        var body: some View {
            if let mac = top as? MacTop {
                Text ("Mac: \(mac.loadAvg)")
            } else if let linux = top as? LinuxTop {
                Text ("Linux: \(linux.loadAvg)")
            } else {
                Text ("Unknown OS")
            }
        }
    }
    
    struct DetailedProcessView: View {
        @Environment(\.sessionEnv) var session: Session
        @ObservedObject var top: Top
        @State var process: ProcessInfo
        @State private var isConfirming = false
        @State private var dialogDetail: ProcessInfo?
        @State var errorKilling = false
        @State var errorMessage = ""

        var body: some View {
            List {
                Section {
                    HStack {
                        Text ("Command:")
                        Spacer ()
                        Text (process.command)
                            .font (.system(.body, design: .monospaced))
                    }
                    HStack {
                        Text ("Process ID:")
                        Spacer ()
                        Text (String (process.pid))
                    }
                    HStack {
                        Text ("CPU Usage:")
                        Spacer ()
                        
                        Text ("\(top.processes.first(where: { $0.pid == process.pid})?.pCpu ?? -1, specifier: "%.2f")%")
                            .font (.body)
                    }
                    HStack (alignment: .firstTextBaseline){
                        Text ("Memory Usage:")
                        Spacer ()
                        VStack (alignment: .trailing){
                            Text ("\(ByteCountFormatter.string(fromByteCount: Int64 (process.pMem * Float ((top.physMemUsed+top.physMemUnused))), countStyle: .memory))")
                            Text ("(\(top.processes.first(where: { $0.pid == process.pid})?.pCpu ?? -1, specifier: "%.2f")%)")
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        Text ("Total Time:")
                        Spacer ()
                        Text ("\(intervalFormatter.string (from: Double (process.time)/100.0) ?? "?")")
                    }
                    ButtonUser (user: process.user)
                }
                
                Button ("Kill Process", role: .destructive, action: {
                    dialogDetail = process
                    isConfirming = true
                })
            }
            .alert ("Error Killing Process", isPresented: $errorKilling, actions: {}, message: { Text ("Remote end returned this error:\n```\(errorMessage)```\n") })
            .confirmationDialog(
                "Are you sure you want to kill this process?",
                isPresented: $isConfirming, presenting: dialogDetail) { detail in
                Button {
                    Task {
                        await session.runSimple(command: "kill -9 \(detail.pid)", resultCallback: { out, err in
                            if let msg = err, msg != "" {
                                errorMessage = msg
                                errorKilling = true
                            }
                        })
                    }
                } label: {
                    Text("Kill process `\(process.command)`")
                }
                Button("Cancel", role: .cancel) {
                    dialogDetail = nil
                }
            }
        }
    }
    
    struct ProcessBarView: View {
        @State var process: ProcessInfo
        @State var value: Float
        @State var bar: CGFloat
        
        var body: some View {
            VStack (spacing: 0){
                HStack (alignment: .firstTextBaseline){
                    
                    Text ("\(process.command)")
                        .font (.system(.body, design: .monospaced))
                    Spacer ()
                    Text ("\(value, specifier: "%.2f")%")
                        .font (.body)
                }
                
                GeometryReader { g in
                    VStack {
                        ChartColors.color3
                            .frame (width: bar*g.size.width)
                    }
                }
                .background(SessionSummaryColors.presentColor)
                .frame (height: 10)
            }
        }
    }
    
    struct ButtonUser: View {
        var user: String
        var body: some View {
            HStack {
                Text ("User: ")
                Button (user, action: {})
                    .font (.system(.footnote, design: .monospaced))
                    .buttonStyle(.bordered)
                    .tint(Color.green)
            }
        }
    }
    
    struct DetailedProcessesView: View {
        enum SortOrder {
            case cpu
            case mem
            case user
            case runTime
        }
        @ObservedObject var top: Top
        @State var sortOrder: SortOrder = .cpu
        @State var invert = false
        @State var showDetailItem: ProcessInfo?

        func sort (first: ProcessInfo, second: ProcessInfo) -> Bool {
            var res: Bool
            switch sortOrder {
            case .cpu:
                res = first.pCpu > second.pCpu
            case .mem:
                res = first.pMem > second.pMem
            case .user:
                res = first.user > second.user ? true : first.pCpu > second.pCpu
            case .runTime:
                res = first.time > second.time
            }
            return invert ? !res : res
        }
        
        struct SummaryProcessView: View {
            @ObservedObject var top: Top
            @State var process: ProcessInfo
            
            var body: some View {
                VStack (alignment: .leading){
                    HStack (alignment: .firstTextBaseline){
                        Text ("\(process.command)")
                            .font (.system(.body, design: .monospaced))
                        Spacer ()
                        Text ("\(process.pCpu, specifier: "%.2f")%")
                            .font (.body)
                    }
                    HStack {
                        ButtonUser (user: process.user)
                    }
                    HStack {
                        Text ("Memory: \(ByteCountFormatter.string(fromByteCount: Int64 (process.pMem * Float ((top.physMemUsed+top.physMemUnused))), countStyle: .memory))")
                        Spacer ()
                        Text ("\(process.pMem*100, specifier: "%.2f")%")
                            .foregroundColor(Color.secondary)
                    }
                    HStack {
                        Text ("Total Time:")
                        Spacer ()
                        Text ("\(intervalFormatter.string (from: Double (process.time)/100.0) ?? "?")")
                            .foregroundColor(Color.secondary)
                    }
                }
            }
        }
        
        func getTitle (_ sortOrder: SortOrder) -> String {
            switch sortOrder {
            case .cpu:
                return "CPU usage"
            case .mem:
                return "Memory usage"
            case .user:
                return "UserID"
            case .runTime:
                return "Total Runtime"
            }
        }
        
        var body: some View {
            List {
                ForEach (top.processes.sorted(by: sort)) { p in
                    ZStack {
                        switch sortOrder {
                        case .cpu:
                            ProcessBarView (process: p, value: p.pCpu, bar: CGFloat (p.pCpu)/100)
                        case .mem:
                            ProcessBarView (process: p, value: p.pMem, bar: CGFloat (p.pMem)/100)
                        case .user, .runTime:
                            SummaryProcessView (top: top, process: p)
                        }
                    }
                    .onTapGesture {
                        showDetailItem = p
                    }
                    .sheet(item: $showDetailItem) { detail in
                        DetailedProcessView (top: top, process: detail)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { sortOrder = .cpu }) {
                            Label("CPU usage", systemImage: "cpu")
                        }
                        Button(action: { sortOrder = .mem }) {
                            Label("Memory usage", systemImage: "memorychip")
                        }
                        Button(action: { sortOrder = .user }) {
                            Label("User", systemImage: "person.3.sequence")
                        }
                        Button(action: { sortOrder = .runTime }) {
                            Label("Total runtime", systemImage: "clock")
                        }
                        Button (action: { invert.toggle() }) {
                            Label ("Reverse", systemImage: invert ? "checkmark" : "")
                        }
                    }
                label: {
                    Text ("Sort order")
                }
                }
            }
            .navigationTitle ("\(getTitle (sortOrder))")
        }
    }
    
    struct ProcessView: View {
        @ObservedObject var top: Top
        @State var showDetails: Bool = false
        @State var showDetailItem: ProcessInfo?

        func f (_ p: ProcessInfo) -> String {
            print (p.debugDescription)
            return p.command
        }
        
        var body: some View {
            ForEach (top.processes.sorted(by: {$0.pCpu > $1.pCpu}).prefix (8), id: \.pid) { p in
                ProcessBarView (process: p, value: p.pCpu, bar: CGFloat (p.pCpu)/100)
                    .animation(.easeIn, value: p.pCpu)
                    .onTapGesture {
                        showDetailItem = p
                    }
                    .sheet(item: $showDetailItem) { detail in
                        DetailedProcessView (top: top, process: detail)
                    }
            }
        }
    }
    
    struct LoadView: View {
        @ObservedObject var top: Top
        @Binding var historicLoad: [Float]

        var body: some View {
            HStack {
                Text ("Load")
                    .font(.title)
                    .foregroundColor(Color.secondary)
                Text ("\(top.loadAvg, specifier: "%2.2f")")
                    .font(.title)
                    .foregroundColor(Color.primary)
                Color.clear
                    .background {
                        SessionLoadHistoryView (historicLoad: $historicLoad)
                            .opacity(0.3)
                            .padding ([.leading])
                    }
            }
        }
    }
    
    // Used when we do not have a Top yet
    struct LoadViewStartup: View {
        @Binding var load: Float
        @Binding var historicLoad: [Float]

        var body: some View {
            HStack {
                Text ("Load")
                    .font(.title)
                    .foregroundColor(Color.secondary)
                Text ("\(load, specifier: "%2.2f")")
                    .font(.title)
                    .foregroundColor(Color.primary)
                Color.clear
                    .background {
                        SessionLoadHistoryView (historicLoad: $historicLoad)
                            .opacity(0.3)
                            .padding ([.leading])
                    }
            }
        }
    }
    
    struct CpuView: View {
        @ObservedObject var top: Top
        
        func getValues () -> [Double] {
            var total = top.cpuSys + top.cpuUser + top.cpuIdle
            
            func frac (v: Double) -> Double {
                v/total
            }
            if let linux = top as? LinuxTop {
                total += linux.cpuNice+linux.cpuWaitingIO+linux.cpuTimeHardwareInt+linux.cpuTimeSoftInt+linux.cpuTimeStolenHypervisor
                
                return [top.cpuSys, top.cpuUser, top.cpuIdle, linux.cpuNice, linux.cpuWaitingIO, linux.cpuTimeHardwareInt, linux.cpuTimeSoftInt, linux.cpuTimeStolenHypervisor].map (frac)
            }

            return [top.cpuSys, top.cpuUser, top.cpuIdle].map (frac)
        }
        
        var body: some View {
            HStack (alignment: .top){
                GaugeView (values: getValues ())
                    .overlay {
                        VStack {
                            Text ("\(top.loadAvg, specifier: "%2.1f")%")
                                .font (.footnote)
                            Text ("CPU")
                                .font (.footnote)
                        }
                    }
                .frame (width: gaugeSize, height: gaugeSize)
                
                VStack {
                    LabeledPercentView (label: "System", color: ChartColors.color1,
                                        text: Text ("\(top.cpuSys, specifier: "%0.2f")%"))
                    LabeledPercentView (label: "User", color: ChartColors.color2,
                                        text: Text ("\(top.cpuUser, specifier: "%0.2f")%"))
                    LabeledPercentView (label: "Idle", color: ChartColors.color3,
                                        text: Text ("\(top.cpuIdle, specifier: "%0.2f")%"))
                }
            }
        }
    }

    struct TaskView: View {
        @ObservedObject var top: Top
        
        func mapProc (_ process: Int) -> Double {
            var extra = 0
            if let linux = top as? LinuxTop {
                extra = linux.processStopped + linux.processZombie
            }
            return Double (process)/Double (top.processRunning + top.processSleeping + extra)
        }
        
        func getValues () -> [Double] {
            var total = Double (top.processRunning + top.processSleeping)
            
            func mapProc (_ process: Int) -> Double {
                return Double (process)/total
            }
            if let linux = top as? LinuxTop {
                total += Double (linux.processStopped + linux.processZombie)
                
                return [mapProc (top.processRunning), mapProc (top.processSleeping),
                        mapProc (linux.processStopped), mapProc (linux.processZombie)]
            }

            return [mapProc (top.processRunning), mapProc (top.processSleeping)]
        }
        
        var body: some View {
            HStack (alignment: .top){
                GaugeView (values: getValues ())
                    .frame (width: gaugeSize, height: gaugeSize)
                    .overlay {
                        VStack {
                            Text ("Tasks")
                                .font (.footnote)
                        }
                    }
                VStack {
                    LabeledPercentView (label: "Running", color: ChartColors.color1,
                                        text: Text ("\(top.processRunning)"))
                    LabeledPercentView (label: "Sleeping", color: ChartColors.color2,
                                        text: Text ("\(top.processSleeping)"))
                    if let linux = top as? LinuxTop {
                        LabeledPercentView (label: "Stopped", color: ChartColors.color3,
                                            text: Text ("\(linux.processStopped)"))
                        LabeledPercentView (label: "Sleeping", color: ChartColors.color4,
                                            text: Text ("\(linux.processSleeping)"))

                    }
                }
            }
        }
    }
    
    struct MemoryView: View {
        @ObservedObject var top: Top
        
        func getValues () -> [Double] {
            let total = Double (top.physMemUsed + top.physMemUnused)
            
            func frac (_ v: Int) -> Double {
                return Double (v)/total
            }
            if let mac = top as? MacTop {
                return [frac (mac.physMemWired), frac (top.physMemUsed-mac.physMemWired), frac (top.physMemUnused)]
            }
            return [frac (top.physMemUsed), frac (top.physMemUnused)]
        }
        
        var body: some View {
            HStack (alignment: .top){
                GaugeView (values: getValues ())
                    .frame (width: gaugeSize, height: gaugeSize)
                    .overlay {
                        VStack {
                            Text ("RAM")
                                .font (.footnote)
                        }
                }.frame (width: gaugeSize, height: gaugeSize)

                VStack {
                    if let mac = top as? MacTop {
                        LabeledPercentView (label: "Wired", color: ChartColors.color1,
                                            text: Text (ByteCountFormatter.string(fromByteCount: Int64(mac.physMemWired), countStyle: .memory)))

                    }
                    LabeledPercentView (label: "Used", color: ChartColors.color2,
                                        text: Text (ByteCountFormatter.string(fromByteCount: Int64(top.physMemUsed), countStyle: .memory)))
                    LabeledPercentView (label: "Free", color: ChartColors.color3,
                                        text: Text (ByteCountFormatter.string(fromByteCount: Int64(top.physMemUnused), countStyle: .memory)))
                }
            }
        }
    }

    var body: some View {
        //VStack {
        List {
            Section {
                LoadView (top: top, historicLoad: $historicLoad)
                CpuView (top: top)
                    .padding ([.bottom])
                TaskView (top: top)
            }
            Section {
                MemoryView (top: top)
            }
            Section ("Top Processes") {
                ProcessView (top: top)
                Button ("Details") { showAllProcesses.toggle () }
            }
        }.sheet (isPresented: $showAllProcesses) {
            NavigationView {
                DetailedProcessesView (top: top)
            }
            .navigationViewStyle(.stack)
            .navigationBarHidden(false)
        }
    }
}

struct SessionKey: EnvironmentKey {
    static let defaultValue: Session = InvalidSession ()
}

extension EnvironmentValues {
    var sessionEnv: Session {
        get { self[SessionKey.self] }
        set { self[SessionKey.self] = newValue }
    }
}

struct HostStatusDetailLoader: View {
    @State var session: Session
    @ObservedObject var loadMonitor: LoadMonitor
    
    // It really is just one, but it is to simplify the binding below
    @State var topMonitor: [TopMonitor] = []
    @State var _monitor: TopMonitor?
    @Binding var active: Bool
    @State var showSummary = true
    
    var body: some View {
        NavigationView {
            VStack {
                if topMonitor.count == 0 {
                    List {
                        if showSummary {
                            Section {
                                HostStatusDetail.LoadViewStartup (load: $loadMonitor.normalizedLoad, historicLoad: $loadMonitor.historicLoad)
                            }
                            Section {
                                HStack {
                                    ProgressView ()
                                        .frame (width: 20, height: 20)
                                    Text ("Sampling CPU Usage...")
                                }
                                HStack {
                                    ProgressView ()
                                        .frame (width: 20, height: 20)
                                    Text ("Sampling Memory Usage...")
                                }
                            }
                        } else {
                            Section {
                                HStack {
                                    ProgressView ()
                                        .frame (width: 20, height: 20)
                                    Text ("Fetching Process List")
                                }
                            }
                        }
                    }
                } else {
                    if showSummary {
                        HostStatusDetail (top: topMonitor [0].top, historicLoad: $loadMonitor.historicLoad)
                    } else {
                        HostStatusDetail.DetailedProcessesView (top: topMonitor [0].top)
                            .navigationViewStyle(.stack)
                            .navigationBarHidden(false)
                    }
                }
            }
            .onChange(of: active) { newVal in
                //
                // This piece of code is just never invoked, no matter what I try.
                // the idea was that when the sheet was dimsissed, this would be invoked,
                // as intended by SwiftUI source of truth, but this just go "meh, no"
                //
                // So to properly shut down the connection, I do that instead in the task,
                // that will be cancelled.
                if newVal == false {
                    if let running = _monitor {
                        running.stop ()
                    }
                    topMonitor = []
                }
            }
            .task {
                if let monitor = await TopMonitor (session, os: await session.getOsKind()) {
                    _monitor = monitor
                    monitor.run()
                    
                    // We wait until the first load of data
                    while !Task.isCancelled && !monitor.ready && monitor.running {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                    if monitor.running && !Task.isCancelled {
                        topMonitor.append (monitor)
                    }

                    // MASSIVE HACK: because I can not find a way to have a notification
                    // when the sheet is dimissed, instead, now I keep waiting for the
                    // task to get cancelled by SwiftUI and then I shut things down.
                    while !Task.isCancelled {
                        do {
                            try await Task.sleep(nanoseconds: 1_000_000_000)
                        } catch {
                            // Shut down
                            monitor.stop()
                            _monitor = nil
                            topMonitor = []
                        }
                    }
                }
            }
            .navigationTitle("System Status")
            .navigationBarHidden(showSummary)
            .environment(\.sessionEnv, session)
        }
    }
}

var n = 0
struct HostStatusDetail_Previews: PreviewProvider {
    struct WrapperView: View {
        @State var top: Top = MacTop (source: (try? String (contentsOfFile: "/Users/miguel/cvs/SwiftTermApp/macos-top")) ?? "")
        @State var historicLoad: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.8, 0.7, 0.2, 0.4]
        func foo () -> String {
            n += 1
            try? Date ().debugDescription.write(toFile: "/tmp/\(n).date", atomically: true, encoding: .utf8)
            return ""
        }
        var body: some View {
            Text (foo ())
            HostStatusDetail (top: top, historicLoad: $historicLoad)
        }
    }
    static var previews: some View {
        WrapperView ()
//            .previewDevice("iPhone 12")
//            .previewLayout(.sizeThatFits)
//            WrapperView ()
//            WrapperView ()
//                .previewDevice(PreviewDevice (rawValue: "iPad Pro (9.7-inch)"))
//                .previewDisplayName("iPad")
    }
}

