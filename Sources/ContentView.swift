import SwiftUI
import UIKit
import CoreMotion
import AudioToolbox
import Darwin

// MARK: - JIT Diagnostic Helper
func checkJITStatus() -> (Bool, String) {
    let size: size_t = 4096
    let ptr = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0)
    if ptr == MAP_FAILED {
        return (false, "mmap 실패")
    }
    defer {
        munmap(ptr, size)
    }
    
    let res = mprotect(ptr, size, PROT_READ | PROT_EXEC)
    if res == 0 {
        return (true, "JIT 정상 활성화됨 (mprotect RX 성공)")
    } else {
        let err = errno
        return (false, "JIT 차단됨 (권한 거부 - errno: \(err))")
    }
}

// MARK: - Motion Manager
class MotionObserver: ObservableObject {
    private let manager = CMMotionManager()
    @Published var accelX: Double = 0.0
    @Published var accelY: Double = 0.0
    @Published var accelZ: Double = 0.0
    
    func start() {
        if manager.isAccelerometerAvailable {
            manager.accelerometerUpdateInterval = 0.1
            manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let data = data else { return }
                self?.accelX = data.acceleration.x
                self?.accelY = data.acceleration.y
                self?.accelZ = data.acceleration.z
            }
        }
    }
    
    func stop() {
        manager.stopAccelerometerUpdates()
    }
}

// MARK: - FPS / Refresh Rate Monitor
class DisplayMonitor: ObservableObject {
    @Published var currentFPS: Int = 0
    @Published var maxFPS: Int = 60
    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var frames: Int = 0
    
    func start() {
        maxFPS = UIScreen.main.maximumFramesPerSecond
        displayLink = CADisplayLink(target: self, selector: #selector(onFrame))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func onFrame(link: CADisplayLink) {
        if lastTime == 0 {
            lastTime = link.timestamp
            return
        }
        frames += 1
        let delta = link.timestamp - lastTime
        if delta >= 1.0 {
            currentFPS = Int(round(Double(frames) / delta))
            frames = 0
            lastTime = link.timestamp
        }
    }
}

// MARK: - Main Diagnostic View
struct ContentView: View {
    @StateObject private var motion = MotionObserver()
    @StateObject private var display = DisplayMonitor()
    
    @State private var jitActive: Bool = false
    @State private var jitDetail: String = "테스트 전"
    @State private var hapticLog: String = "햅틱 버튼을 눌러보세요"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 4) {
                        Text("⚡ Chan Tester")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("iPhone 15 Pro & Sideload Diagnostics")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 8)
                    
                    // 1. JIT Check Section
                    card(title: "⚡ JIT (Just-In-Time) 인타이틀먼트", icon: "bolt.shield.fill", color: .yellow) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("상태:")
                                    .fontWeight(.semibold)
                                Text(jitActive ? "ACTIVE" : "INACTIVE")
                                    .fontWeight(.bold)
                                    .foregroundColor(jitActive ? .green : .red)
                                Spacer()
                                Button(action: runJITCheck) {
                                    Text("JIT 재검사")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.yellow.opacity(0.2))
                                        .foregroundColor(.yellow)
                                        .cornerRadius(8)
                                }
                            }
                            Text(jitDetail)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 2. Display & ProMotion 120Hz Section
                    card(title: "🖥️ 디스플레이 & ProMotion 120Hz", icon: "speedometer", color: .cyan) {
                        VStack(spacing: 12) {
                            HStack {
                                metricItem(label: "최대 주사율", value: "\(display.maxFPS) Hz")
                                Spacer()
                                metricItem(label: "실시간 렌더링", value: "\(display.currentFPS) FPS")
                                Spacer()
                                metricItem(label: "화면 스케일", value: String(format: "%.0fx Retina", UIScreen.main.scale))
                            }
                            Text("iPhone 15 Pro의 ProMotion 120Hz 동적 가변 주사율 측정")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 3. Taptic Engine / Haptics Section
                    card(title: "📳 Taptic Engine 햅틱 피드백", icon: "iphone.radiowaves.left.and.right", color: .purple) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("다양한 햅틱 모터를 직접 테스트해 보세요:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                hapticButton(title: "Light", color: .blue) { triggerImpact(.light) }
                                hapticButton(title: "Medium", color: .indigo) { triggerImpact(.medium) }
                                hapticButton(title: "Heavy", color: .purple) { triggerImpact(.heavy) }
                                hapticButton(title: "Rigid", color: .orange) { triggerImpact(.rigid) }
                                hapticButton(title: "Soft", color: .teal) { triggerImpact(.soft) }
                                hapticButton(title: "Success", color: .green) { triggerNotif(.success) }
                                hapticButton(title: "Warning", color: .yellow) { triggerNotif(.warning) }
                                hapticButton(title: "Error", color: .red) { triggerNotif(.error) }
                                hapticButton(title: "Select", color: .pink) { triggerSelect() }
                            }
                            
                            Text("마지막 작동: \(hapticLog)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 4. Accelerometer / Sensors Section
                    card(title: "🧭 3축 가속도계 센서 (CoreMotion)", icon: "gyroscope", color: .green) {
                        VStack(spacing: 8) {
                            HStack {
                                sensorBar(axis: "X (좌우)", val: motion.accelX, color: .red)
                                sensorBar(axis: "Y (상하)", val: motion.accelY, color: .green)
                                sensorBar(axis: "Z (앞뒤)", val: motion.accelZ, color: .blue)
                            }
                            Text("기기를 기울여 3축 가속도 변화를 실시간으로 확인하세요.")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 5. Hardware & System Specs
                    card(title: "📱 시스템 & 하드웨어 스펙", icon: "cpu", color: .orange) {
                        VStack(spacing: 6) {
                            infoRow(label: "기기 명칭", val: UIDevice.current.model)
                            infoRow(label: "iOS 버전", val: UIDevice.current.systemVersion)
                            infoRow(label: "CPU 활성 코어", val: "\(ProcessInfo.processInfo.activeProcessorCount) Cores")
                            infoRow(label: "물리 RAM 메모리", val: getMemoryString())
                            infoRow(label: "발열 상태", val: getThermalString())
                            infoRow(label: "저전력 모드", val: ProcessInfo.processInfo.isLowPowerModeEnabled ? "켜짐" : "꺼짐")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
            .onAppear {
                runJITCheck()
                motion.start()
                display.start()
            }
            .onDisappear {
                motion.stop()
                display.stop()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // Helpers
    private func runJITCheck() {
        let (status, msg) = checkJITStatus()
        jitActive = status
        jitDetail = msg
    }
    
    private func triggerImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
        hapticLog = "Impact (\(style))"
    }
    
    private func triggerNotif(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(type)
        hapticLog = "Notification (\(type))"
    }
    
    private func triggerSelect() {
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
        hapticLog = "Selection Changed"
    }
    
    private func getMemoryString() -> String {
        let bytes = ProcessInfo.processInfo.physicalMemory
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        return String(format: "%.1f GB", gb)
    }
    
    private func getThermalString() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "정상 (Nominal)"
        case .fair: return "약간 발열 (Fair)"
        case .serious: return "높은 발열 (Serious)"
        case .critical: return "위험 (Critical)"
        @unknown default: return "알 수 없음"
        }
    }
    
    // UI Builders
    private func card<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.headline)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Divider().background(Color.gray.opacity(0.3))
            content()
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.3))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func metricItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.cyan)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
    
    private func hapticButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(8)
        }
    }
    
    private func sensorBar(axis: String, val: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(axis)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(String(format: "%+.2f", val))
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.4))
        .cornerRadius(6)
    }
    
    private func infoRow(label: String, val: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(val)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}
