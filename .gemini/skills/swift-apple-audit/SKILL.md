---
name: swift-apple-audit
description: Auditoría de código Swift 6.3+ basada en las mejores prácticas de Apple Developer (Concurrencia Estricta, MVVM, SwiftUI). Úsala para revisar proyectos iOS/macOS en busca de problemas de seguridad en hilos, ciclos de retención y arquitectura moderna.
---

# Swift Apple Audit

## Overview

Este agente especializado audita el código Swift para asegurar el cumplimiento de los estándares modernos de Apple (Swift 6.3+). Se enfoca en la migración a la concurrencia estricta, la seguridad en hilos mediante actores y la optimización de vistas en SwiftUI.

## Workflow de Auditoría

1.  **Escaneo Automatizado:** Ejecuta el script de auditoría estática para identificar patrones anti-Swift 6 y problemas de memoria comunes.
    - Ejecuta: `python3 scripts/swift_audit.py <project_path>`
2.  **Revisión de Concurrencia:** Verifica el aislamiento de los ViewModels mediante `@MainActor` y la conformidad con `Sendable`. Consulta [apple-swift-guidelines.md](references/apple-swift-guidelines.md).
3.  **Análisis de Arquitectura:** Asegura que los servicios compartidos utilicen `actor` y que la UI use patrones reactivos modernos (macros `@Observable`).
4.  **Informe de Hallazgos:** Genera un reporte estructurado con métricas claras y propuestas de refactorización quirúrgicas.

## Tareas Comunes

### Ejecutar Escaneo Inicial
Para obtener una visión general de los puntos críticos del proyecto:
`python3 scripts/swift_audit.py .`

### Revisar Guías de Apple
Si no estás seguro de un patrón (ej. migración de GCD a async/await), lee la guía de referencia:
`read_file references/apple-swift-guidelines.md`

### Auditoría Manual de ViewModel
Busca clases en `ViewModels/` y verifica:
- Uso de `@MainActor`.
- Uso de `Task` para operaciones asíncronas.
- Ausencia de `DispatchQueue.main.async`.

## Recursos

- **scripts/swift_audit.py**: Script de análisis estático rápido.
- **references/apple-swift-guidelines.md**: Compendio de estándares de Apple para Swift 6 y SwiftUI.
