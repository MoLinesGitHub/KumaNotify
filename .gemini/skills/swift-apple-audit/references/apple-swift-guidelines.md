# Guía de Buenas Prácticas de Apple para Swift 6+ y SwiftUI

Esta referencia detalla los estándares de ingeniería para proyectos modernos en Swift 6.3+, con enfoque en concurrencia estricta, arquitectura MVVM y SwiftUI.

## 1. Concurrencia Estricta (Swift 6)

El objetivo es eliminar las carreras de datos (*data races*) en tiempo de compilación.

### A. Aislamiento de Actores
- **ViewModels:** Deben marcarse con `@MainActor` para garantizar que las actualizaciones de la UI ocurran en el hilo principal.
- **Servicios de Estado:** Usar `actor` para recursos compartidos mutables (cachés, DB, managers).
- **Global Actors:** Usar `@MainActor` en singletons que manejan UI.

### B. Protocolo `Sendable`
- Los datos que cruzan fronteras de aislamiento (ej. de un Actor de fondo al Main Actor) deben ser `Sendable`.
- Preferir `struct` y `enum` sobre `class` para modelos de datos.
- Las clases `Sendable` deben ser `final` y tener solo propiedades inmutables (`let`).

### C. Evitar GCD Tradicional
- Reemplazar `DispatchQueue.main.async` por `@MainActor` o `Task { @MainActor in ... }`.
- Usar `Task` para trabajo asíncrono desde contextos síncronos.
- Usar `Task.detached` solo cuando se requiera explícitamente romper la herencia de aislamiento (raro).

## 2. SwiftUI y MVVM

### A. Estructura de la Vista
- Mantener las vistas pequeñas y especializadas.
- Usar `@State` para estado privado y efímero de la vista.
- Usar `@StateObject` (iOS 14-16) o `@State` con `@Observable` (iOS 17+) para ViewModels.

### B. Gestión de Datos
- **Environment:** Usar `.environment()` o `@EnvironmentObject` para datos globales o compartidos en el árbol de vistas.
- **Bindings:** Usar `@Binding` para permitir que vistas hijas modifiquen estado de padres sin poseerlo.

## 3. Calidad de Código y Rendimiento

### A. Gestión de Memoria
- Evitar ciclos de retención fuertes en ViewModels y clousures usando `[weak self]`.
- No usar `unowned` a menos que la vida del objeto esté garantizada (peligroso).

### B. Tipado Fuerte
- Usar `Result` para manejo de errores en APIs asíncronas antiguas.
- Preferir `async/await` con `throws` en código nuevo.

## 4. Checklist de Auditoría

1. ¿Están todos los ViewModels marcados con `@MainActor`?
2. ¿Los modelos de datos son `Sendable` (preferiblemente `struct`)?
3. ¿Se está usando `actor` para servicios con estado compartido?
4. ¿Hay algún uso innecesario de `DispatchQueue` que pueda ser `async/await`?
5. ¿Se manejan correctamente los ciclos de retención (`[weak self]`)?
6. ¿Se están usando los nuevos macros de observación (`@Observable`) si el target es iOS 17+?
