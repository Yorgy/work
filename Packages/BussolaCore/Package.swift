// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BussolaCore",
    // iOS 26 é o alvo real da app. O mínimo de macOS existe só para `swift test`
    // correr num Mac sem exigir a versão mais recente do sistema: o domínio é
    // Swift puro e a persistência precisa apenas de SwiftData.
    platforms: [.iOS(.v26), .macOS(.v14)],
    products: [
        .library(name: "BussolaDomain", targets: ["BussolaDomain"]),
        .library(name: "BussolaPersistence", targets: ["BussolaPersistence"]),
        .library(name: "BussolaTriage", targets: ["BussolaTriage"]),
        .library(name: "BussolaBridge", targets: ["BussolaBridge"]),
    ],
    targets: [
        // Swift puro. Sem SwiftData, SwiftUI ou EventKit — ver ADR-009.
        // Compila e testa em Linux, o que mantém o ciclo de feedback em segundos.
        .target(name: "BussolaDomain"),

        .target(name: "BussolaPersistence", dependencies: ["BussolaDomain"]),
        .target(name: "BussolaTriage", dependencies: ["BussolaDomain"]),
        .target(name: "BussolaBridge", dependencies: ["BussolaDomain"]),

        .testTarget(name: "BussolaDomainTests", dependencies: ["BussolaDomain"]),
        .testTarget(name: "BussolaPersistenceTests", dependencies: ["BussolaPersistence"]),
    ]
)
