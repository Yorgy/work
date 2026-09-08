// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BussolaCore",
    // Estes mínimos são os do *pacote*, não os da app. O alvo real da app é iOS
    // 26 e está declarado em `project.yml`.
    //
    // O pacote fica deliberadamente mais baixo por duas razões: `swift test`
    // corre em qualquer Mac com Xcode ou Command Line Tools recentes, e tudo o
    // que precisa de iOS 26 — só a triagem com FoundationModels — já está
    // guardado com `#if canImport` e `@available`. Declarar `.v26` aqui obrigava
    // a `swift-tools-version: 6.2` e a um toolchain novíssimo, sem que nenhum
    // ficheiro do pacote o exigisse.
    platforms: [.iOS(.v17), .macOS(.v14)],
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
