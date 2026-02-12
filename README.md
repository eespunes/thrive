# 📱 Product Backlog: Thrive (Detailed)

**Proyecto:** Gestor de Finanzas Familiares (Android + Web)
**Stack Tecnológico:** React Native (Expo) + Firebase (Firestore/Auth)
**Objetivo:** Reemplazo total de Excel con soporte Multi-usuario y Offline.
**Versión:** 1.0 (MVP)

---

## 🟢 EPIC 1: Onboarding y Arquitectura Familiar
*Infraestructura base para la gestión de usuarios y hogares.*

### US-1.1: Autenticación y Perfil
**Como** usuario, **quiero** iniciar sesión con Google, **para** entrar rápido sin recordar contraseñas.
- [ ] Implementar pantalla de Login con botón "Sign in with Google".
- [ ] Crear documento de usuario en Firestore (`users/{uid}`) al primer login.
- [ ] Persistencia de sesión (Token refresh automático).

### US-1.2: Creación del "Hogar" (Workspace)
**Como** usuario nuevo, **quiero** crear un grupo familiar o unirme a uno, **para** compartir gastos.
- [ ] Flujo "Crear Familia": Generar ID único y asignar rol `admin` al creador.
- [ ] Flujo "Unirse": Input para pegar Código de Invitación.
- [ ] Validación: Añadir usuario al array `members` de la familia en DB.

### US-1.3: Configuración de Cuentas (Wallets)
**Como** familia, **quiero** definir qué cuentas tenemos (ING, ABN, Efectivo), **para** saber de dónde sale el dinero.
- [ ] CRUD (Crear/Leer/Editar/Borrar) de cuentas.
- [ ] Propiedades: Nombre, Icono, Propietario (¿Es cuenta conjunta o personal?).
- [ ] **Regla:** Crear cuenta "Efectivo" por defecto.

---

## 💸 EPIC 2: Motor de Transacciones (Income & Expenses)
*Entrada rápida de datos para eliminar la fricción.*

### US-2.1: Registro de Gasto Rápido (Smart Input)
**Como** usuario, **quiero** registrar un gasto en menos de 5 segundos, **para** no olvidar hacerlo.
- [ ] Botón flotante (+) visible en todas las pantallas principales.
- [ ] Formulario: Monto (Teclado grande), Concepto, Categoría (Iconos).
- [ ] Selector "Pagado con": Dropdown de las cuentas activas.
- [ ] **Web:** Soporte para navegación con teclado (Tab/Enter).

### US-2.2: Registro de Ingresos (Income)
**Como** familia, **quiero** registrar nuestras nóminas y ayudas, **para** calcular el ahorro mensual.
- [ ] Toggle en formulario: "Gasto" vs "Ingreso".
- [ ] Selector de categorías de ingreso (Salario, Bonus, Belastingdienst).
- [ ] Visualización en Dashboard: "Total Ingresado vs. Total Gastado".

### US-2.3: Transacciones Recurrentes (Automatización)
**Como** usuario, **quiero** que el alquiler se registre solo el día 1, **para** no tener que meterlo manualmente.
- [ ] Opción "Repetir" en el formulario.
- [ ] Frecuencia: Mensual, Semanal, Anual.
- [ ] Lógica técnica: Verificación al inicio de la app para generar pendientes.

---

## 🏦 EPIC 3: Deudas y Pasivos (Debt Tracker)
*Funcionalidad crítica migrada del Excel "Debt".*

### US-3.1: Alta de Pasivo/Deuda
**Como** usuario, **quiero** registrar un préstamo con su fecha final, **para** saber cuándo terminaré de pagar.
- [ ] Nuevo tipo de entidad: "Deuda".
- [ ] Campos: Acreedor (ej: Tinka), Monto Total, Cuota Mensual.
- [ ] **Cálculo:** Auto-calcular fecha final basada en Monto Restante / Cuota.

### US-3.2: Visualización de Progreso
**Como** usuario, **quiero** ver una barra de progreso de mis deudas, **para** motivarme.
- [ ] Lista de deudas activas en Dashboard.
- [ ] Barra visual: % Pagado (Verde) vs. % Restante (Gris).
- [ ] Texto dinámico: "Te quedan X meses para finalizar".

---

## ⚖️ EPIC 4: Settlement (Balance de Pareja)
*Resolución de conflictos financieros.*

### US-4.1: Atribución del Gasto (Split Logic)
**Como** usuario, **quiero** indicar para quién es el gasto, **para** que las cuentas cuadren.
- [ ] Opción "¿Para quién?" en formulario.
- [ ] Opciones: "Familia" (50/50), "Para Mí" (Personal), "Pareja" (Regalo).

### US-4.2: Dashboard de Saldos
**Como** pareja, **quiero** ver quién ha pagado más este mes, **para** ajustar cuentas.
- [ ] Pantalla "Balance".
- [ ] Fórmula: `(Pagado por A para casa) - (Pagado por B para casa) / 2`.
- [ ] Resultado visual: "Erik debe 150€ a Eva" o "Estáis en paz".
- [ ] Botón "Liquidar": Crea transferencia virtual para resetear contador.

---

## 📊 EPIC 5: Visualización y Datos (Dashboard)
*Análisis visual y soporte Web.*

### US-5.1: Listado de Movimientos (Feed)
**Como** usuario, **quiero** ver los últimos movimientos ordenados, **para** revisar errores.
- [ ] Lista infinita agrupada por fechas ("Hoy", "Ayer").
- [ ] Fila: Icono, Nombre, Avatar de quién pagó, Monto.
- [ ] Detalle al tocar (Editar/Borrar).

### US-5.2: Tabla "Excel Mode" (Solo Web)
**Como** usuario de escritorio, **quiero** ver una tabla densa, **para** editar rápido.
- [ ] Vista de Data Grid (filas compactas).
- [ ] Columnas ordenables.
- [ ] Filtros por rango de fechas y categorías.

---

## ⚙️ EPIC 6: Arquitectura y DevOps (Technical Foundation)
*Los cimientos invisibles que hacen que la app funcione.*

### US-6.1: Configuración del Proyecto (Expo + Monorepo)
- [ ] Inicializar proyecto con **Expo Router** (navegación basada en ficheros, vital para Web URLs).
- [ ] Configurar **NativeWind (TailwindCSS)** para estilos universales (Móvil + Web).
- [ ] Configurar **TypeScript** estricto.
- [ ] Configurar Alias de importación (`@/components`, `@/utils`).

### US-6.2: Gestión de Estado y Datos (The Brain)
- [ ] Instalar **TanStack Query (React Query)**.
    - *Por qué:* Maneja caché, loading states y re-intentos automáticos si falla internet.
- [ ] Crear Hooks personalizados para Firestore: `useTransactions()`, `useFamily()`.
- [ ] Configurar **Optimistic Updates**: La UI se actualiza *antes* de que el servidor responda (sensación de velocidad instantánea).

### US-6.3: Seguridad y Reglas (Firestore Rules)
- [ ] Escribir reglas de seguridad en `firestore.rules`.
    - Bloquear lectura/escritura si `request.auth` es null.
    - Bloquear acceso a documentos de familias a las que el usuario no pertenece (`resource.data.members`).

### US-6.4: Despliegue (CI/CD)
- [ ] Configurar **EAS Build** (Expo Application Services) para generar APKs de Android.
- [ ] Configurar **Firebase Hosting** para la versión Web.
- [ ] Script `npm run deploy:web` que hace el build y sube a Firebase.

### US-6.5: Offline First
- [ ] Habilitar `enableIndexedDbPersistence` en Firestore (Web).
- [ ] Verificar persistencia nativa en Android (activada por defecto en SDK móvil).
- [ ] Manejo de errores visual (Toast) si la sincronización falla.

---

## 🎨 EPIC 7: Design System & UI Kit (Frontend Foundation)
*Infraestructura visual para asegurar consistencia y desarrollo rápido.*

- [ ] **FEATURE 7.1: Configuración de Tema (Theming)**
  - [ ] Configurar `tailwind.config.js` (NativeWind) con paleta de colores (Primary, Danger, Success).
  - [ ] Definir tipografías (ej: Inter/Roboto) y escala de textos (`text-xl`, `text-sm`).
  - [ ] Implementar soporte para **Dark Mode** (detección automática de sistema).

- [ ] **FEATURE 7.2: Biblioteca de Componentes Atómicos (Atoms)**
  - [ ] Componente `Button`: Variantes (Solid, Outline, Ghost) y estados (Loading, Disabled).
  - [ ] Componente `Input`: Con label flotante, icono opcional y mensaje de error.
  - [ ] Componente `Card`: Contenedor base con sombra y bordes redondeados.
  - [ ] Componente `Avatar`: Círculo para iniciales de usuario o imagen de perfil.

- [ ] **FEATURE 7.3: Layout Responsivo (Responsive Wrapper)**
  - [ ] Componente `ScreenContainer`: Manejo de Safe Area (Notch) en móvil.
  - [ ] Componente `WebContainer`: Limitador de ancho (`max-w-screen-lg` centrado) para escritorio.
  - [ ] Sistema de Grid: Columnas flexibles (1 col en móvil -> 3 cols en web).

---

## 🧭 EPIC 8: Navegación y Experiencia de Usuario (UX)
*Arquitectura de navegación híbrida (Móvil vs Web).*

- [ ] **FEATURE 8.1: Navegación Adaptativa (Expo Router)**
  - [ ] **Móvil:** Implementar `BottomTabs` (Home, + , Movimientos, Perfil).
  - [ ] **Web:** Implementar `Sidebar` (Barra lateral) o `TopBar` persistente.
  - [ ] Configurar Deep Linking: Mapeo de URLs (`/debt/123`) a pantallas nativas.

- [ ] **FEATURE 8.2: Feedback Visual y Estados**
  - [ ] Componente `SkeletonLoader`: Placeholder animado mientras cargan los datos.
  - [ ] Sistema de `Toasts/Snackbars`: Notificaciones flotantes ("Guardado con éxito") no intrusivas.
  - [ ] Manejo de Pantallas de Error: UI amigable cuando falla la carga o no hay internet.

- [ ] **FEATURE 8.3: Modales y Bottom Sheets**
  - [ ] **Móvil:** Implementar `BottomSheet` (panel deslizable desde abajo) para formularios rápidos.
  - [ ] **Web:** Adaptar `BottomSheet` a `Dialog Modal` (ventana centrada) en pantallas grandes.

---

## 📈 EPIC 9: Visualización de Datos (Frontend)
*Representación gráfica de la información financiera.*

- [ ] **FEATURE 9.1: Gráficos Interactivos**
  - [ ] Integrar librería de gráficos (ej: `victory-native` o `react-native-skia`).
  - [ ] Componente `DonutChart`: Distribución de gastos por categoría.
  - [ ] Componente `BarChart`: Histórico de gastos vs. ingresos (últimos 6 meses).
  - [ ] Tooltips: Mostrar valor exacto al tocar/pasar el cursor sobre una barra.

- [ ] **FEATURE 9.2: Formateo y Localización**
  - [ ] Utilidad `formatCurrency`: Manejo correcto de moneda (ej: "1.200,50 €" vs "€1,200.50").
  - [ ] Utilidad `formatDate`: Fechas relativas ("Hoy", "Ayer") y absolutas ("12 Oct 2026").
