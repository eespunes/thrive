# 📱 Documentación de Diseño: Thrive Family Finance (Full MVP)

Este documento detalla el flujo de usuario completo, desde la apertura de la app (Onboarding) hasta la gestión avanzada, enlazando cada pantalla con su Historia de Usuario (US) y su Mockup visual.

---

## 🔄 Diagrama de Flujo de Usuario (User Flow)

```mermaid
graph TD
    %% Flujo de Entrada (Onboarding)
    Splash[Pantalla 01: Splash Screen] --> Login[Pantalla 02: Login / Registro]
    Login --> Choice[Pantalla 03: Crear o Unirse a Familia]
    
    Choice -->|Crear| CreateFam[Pantalla 04: Crear Familia]
    Choice -->|Unirse| JoinFam[Pantalla 05: Unirse a Familia]
    
    CreateFam --> Dashboard[Pantalla 06: Dashboard Principal]
    JoinFam --> Dashboard

    %% Flujo Principal (Core)
    Dashboard -->|Botón +| AddTx[Pantalla 10: Añadir Transacción]
    AddTx -->|Seleccionar| CatSel[Pantalla 11: Selector Categoría]
    CatSel -->|Confirmar| AddTx
    
    Dashboard -->|Clic en Tarjeta| CatDetail[Pantalla 12: Detalle Categoría]
    CatDetail -->|Editar| EditLimit[Pantalla 13: Editar Límite]
    
    Dashboard -->|Ver Reportes| Reports[Pantalla 16: Estadísticas Mensuales]
    Dashboard -->|Ver Movimientos| History[Pantalla 07: Historial Movimientos]
    
    %% Flujo de Gestión
    Dashboard -->|Tab Deudas| Balance[Pantalla 08: Balance Familiar]
    Dashboard -->|Tab Metas| Goals[Pantalla 18: Metas Ahorro]
    Dashboard -->|Menú| Settings[Pantalla 09: Ajustes]
    
    Settings --> Members[Pantalla 14: Gestión Miembros]
    Settings --> Subs[Pantalla 17: Suscripciones]
    Members --> LocalProf[Pantalla 15: Crear Perfil Local]