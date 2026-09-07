// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BussolaCore",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "BussolaDomain", targets: ["BussolaDomain"]),
        .library(name: "BussolaPersistence", targets: ["BussolaPersistence"]),
        .library(name: "BussolaTriage", targets: ["BussolaTriage"]),
    ],
    targets: [
        // Swift puro. Sem SwiftData, SwiftUI ou EventKit — ver ADR-009.
        // Compila e testa em Linux, o que mantém o ciclo de feedback em segundos.
        .target(name: "BussolaDomain"),

        .target(name: "BussolaPersistence", dependencies: ["BussolaDomain"]),
        .target(name: "BussolaTriage", dependencies: ["BussolaDomain"]),

        .testTarget(name: "BussolaDomainTests", dependencies: ["BussolaDomain"]),
        .testTarget(name: "BussolaPersistenceTests", dependencies: ["BussolaPersistence"]),
    ]
)
