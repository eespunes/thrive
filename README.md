# Thrive

<p align="center">
  <img src="logos/thrive-colored.svg" alt="Thrive Logo" width="180" />
</p>

<p align="center">
  App de finanzas familiares para Android e iOS, diseñada para reemplazar el flujo actual en Excel.
</p>

## Resumen
Thrive centraliza la gestión financiera del hogar en una app móvil colaborativa: movimientos, presupuestos, deudas, gastos fijos, metas y organización familiar por fases.

## Visión
Construir un **Family OS**: empezar por finanzas compartidas y evolucionar a una plataforma integral de gestión del hogar.

## Problema
- Información dispersa en hojas de cálculo.
- Dificultad para saber quién pagó qué y qué queda pendiente.
- Seguimiento manual de deudas, recurrencias y cierres de mes.

## Solución
- Registro rápido de ingresos y gastos con categorías.
- Workspace familiar compartido con roles.
- Seguimiento de deudas, gastos fijos y metas de ahorro.
- Balance mensual esperado vs real y pendientes de pago.
- Base técnica para sincronización en tiempo real y soporte offline.

## Stack tecnológico
- **Frontend:** Flutter (Dart) para Android + iOS
- **Estado:** Riverpod + patrón repositorio
- **Backend:** Firebase (Auth, Firestore, Cloud Functions)
- **UI:** Material 3 con branding Thrive
- **CI/CD:** GitHub Actions (Android) y pipeline de releases

## Roadmap
### Fase 1: MVP Finanzas (Core)
Objetivo: reemplazar el Excel familiar con un flujo móvil estable y colaborativo.
- Autenticación y onboarding familiar
- Dashboard mensual y movimientos
- Deudas, gastos fijos, reportes y metas
- Ajustes, miembros y perfiles locales

### Fase 2: Engagement y gestión del hogar
Objetivo: aumentar el uso diario más allá del registro financiero.
- Lista de compra conectada a presupuesto
- Comparador de cesta entre supermercados
- Tareas compartidas del hogar

### Fase 3: Organización familiar
Objetivo: centralizar planificación y calendario familiar.
- Calendario compartido
- Sincronización de eventos financieros
- Importación de calendarios externos

### Fase 4: Inteligencia
Objetivo: convertir datos en acciones y recomendaciones útiles.
- Chat contextual sobre finanzas
- OCR de tickets/facturas
- Briefing diario proactivo
- Simulaciones de escenarios

## Estado actual
- Definición funcional y técnica en progreso con OpenSpec.
- Backlog estructurado por fases con épicas e issues en GitHub.
- Base Flutter iniciada y branding integrado.

## Documentación
- Specs OpenSpec: `openspec/specs/`
- Índice de specs: `openspec/specs/README.md`
- Setup Android release: `.github/ANDROID_RELEASE_SETUP.md`

## Estructura del repositorio
```text
thrive/
├── app/                  # App Flutter
├── openspec/specs/       # Especificaciones funcionales y técnicas
├── mockups/              # Referencias visuales y diagrama de flujo
└── .github/              # Workflows y plantillas de GitHub
```

## Cómo ejecutar (local)
```bash
cd app
flutter pub get
flutter run
```

## Licencia
Privado / uso interno del proyecto.
