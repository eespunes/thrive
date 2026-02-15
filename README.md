# Thrive

Thrive es una app de finanzas familiares para Android e iOS que reemplaza el flujo actual en Excel con colaboración multiusuario, sincronización en tiempo real y soporte offline.

## Vision
Construir un "Family OS": empezar por finanzas compartidas y evolucionar hacia una plataforma integral para la gestion del hogar.

## Problema Que Resuelve
- Registro financiero familiar disperso en hojas de calculo.
- Dificultad para saber quien pago que y cuanto falta por ajustar.
- Seguimiento manual de deudas, ingresos recurrentes y gastos del dia a dia.

## Solucion
- Gestion de movimientos (gastos e ingresos) con captura rapida.
- Espacios familiares compartidos con roles y wallets.
- Debt tracker para pasivos y progreso de pago.
- Settlement de pareja para balance mensual y liquidacion.
- Base tecnica para experiencia offline-first en mobil.

## Stack Tecnologico
- Frontend: Flutter (Dart) para Android + iOS
- Backend: Firebase (Auth + Firestore + Cloud Functions)
- Estado y datos: Riverpod + repositorios para acceso a datos
- Estilos/UI: Material 3 con tema personalizado
- Deployment: CI/CD para Android e iOS (GitHub Actions/Codemagic + Fastlane)

## Alcance Del MVP (Fase 1)
- Autenticacion con Google y perfil de usuario.
- Creacion y union a "hogares" (workspace familiar).
- CRUD de wallets con cuenta por defecto.
- Registro rapido de gastos, ingresos y recurrencias.
- Seguimiento de deudas con estimacion de fin.
- Dashboard de balance entre pareja (settlement).
- Feed de movimientos y modo compacto mobil.
- Fundaciones tecnicas: seguridad Firestore, CI/CD, offline-first.

## Roadmap

## 🟢 Fase 1: MVP Finanzas (Core)
**Objetivo:** Crear una base sólida, rápida y útil que reemplace al Excel actual.
* **Autenticación:** Login Social (Google) y gestión de perfiles.
* **Dashboard:** Visión general de saldo, gastos del mes y accesos rápidos.
* **Movimientos:** Registro de ingresos y gastos con categorías.
* **Deudas (Debt Tracker):** Seguimiento de préstamos y objetivos a largo plazo.
* **Balance (Settlement):** Cálculo automático de "quién debe a quién" entre la pareja.
* **Ajustes:** Configuración de familia y moneda.

---

## 🟡 Fase 2: Engagement & Gestión del Hogar
**Objetivo:** Generar uso diario y resolver la gestión doméstica más allá del dinero.
* **Listas Inteligentes:**
    * Lista de la Compra conectada a presupuestos (ver gasto estimado en tiempo real), con supermercados favoritos/cercanos y búsqueda de productos por supermercado.
    * Comparador de cesta por supermercado (ej: Albert Heijn, Poiesz, Aldi, Jumbo) con indicador de actualización/confianza de precios.
    * Listas de tareas compartidas.

---

## 🟠 Fase 3: Organización
**Objetivo:** Centralizar la gestión del tiempo familiar.
* **Calendario Compartido:**
    * Eventos familiares (Médicos, Cumpleaños, Reuniones escolares).
    * Sincronización con eventos financieros (ej: vencimiento de facturas).

---

## 🟣 Fase 4: Inteligencia (Gemini AI Agent)
**Objetivo:** Convertir los datos en conversaciones y acciones proactivas.
* **Chat Contextual:** Preguntar a la app sobre tus datos (*"¿Cuánto gastamos en comer fuera el mes pasado?"*).
* **OCR Inteligente:** Escaneo de tickets y facturas con extracción automática de datos.
* **Briefing Matutino:** Resumen diario proactivo (*"Hoy tienes dentista a las 10:00 y recuerda que vence el seguro del coche"*).
* **Simulaciones:** Escenarios "What if" (*"¿Podemos permitirnos un coche nuevo?"*).

## Estado Del Proyecto
- Estado: definicion funcional y tecnica del MVP.
- Especificaciones: disponibles en OpenSpec.
- Ruta: `openspec/specs/`

## Documentacion Relacionada
- Specs funcionales (OpenSpec): `/Users/erikespunesjubero/thrive/openspec/specs/`

## Notas
El backlog detallado de user stories y features se modela y valida en OpenSpec para mantener trazabilidad de requisitos por modulo.
