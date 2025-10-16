# Configuración del Sistema de Salud

## Variables de Entorno

Cree un archivo `.env` en la raíz del proyecto con las siguientes variables:

```env
SUPABASE_URL=your_supabase_url_here
SUPABASE_ANON_KEY=your_supabase_anon_key_here
```

## Configuración de Supabase

### 1. Base de Datos

Ejecute estos comandos SQL en el editor de Supabase:

```sql
-- Crear tabla usuarios
CREATE TABLE usuarios (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    nombres TEXT NOT NULL,
    apellidos TEXT NOT NULL,
    cedula TEXT UNIQUE NOT NULL,
    eps TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla citas_medicas
CREATE TABLE citas_medicas (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    tipo_cita TEXT NOT NULL,
    doctor TEXT NOT NULL,
    fecha DATE NOT NULL,
    hora TIME NOT NULL,
    pdf_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS (Row Level Security)
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE citas_medicas ENABLE ROW LEVEL SECURITY;

-- Políticas para usuarios
CREATE POLICY "Usuarios pueden ver sus propios datos" ON usuarios
    FOR SELECT USING (true);

CREATE POLICY "Usuarios pueden insertar sus datos" ON usuarios
    FOR INSERT WITH CHECK (true);

-- Políticas para citas_medicas
CREATE POLICY "Usuarios pueden ver sus citas" ON citas_medicas
    FOR SELECT USING (true);

CREATE POLICY "Usuarios pueden insertar citas" ON citas_medicas
    FOR INSERT WITH CHECK (true);
```

### 2. Storage (Bucket)

1. Vaya a Storage en el panel de Supabase
2. Cree un bucket llamado `bucket1`
3. Configure las políticas del bucket:

```sql
-- Política para subir archivos
CREATE POLICY "Usuarios pueden subir archivos" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'bucket1');

-- Política para ver archivos
CREATE POLICY "Usuarios pueden ver archivos" ON storage.objects
    FOR SELECT USING (bucket_id = 'bucket1');
```

## Instalación y Ejecución

1. Instale las dependencias:
```bash
flutter pub get
```

2. Ejecute la aplicación:
```bash
flutter run
```

## Funcionalidades

- ✅ Registro de usuarios con cédula y EPS
- ✅ Inicio de sesión sin contraseña
- ✅ Agendamiento de citas médicas
- ✅ Subida de archivos PDF (historias clínicas)
- ✅ Navegación fluida entre pantallas
- ✅ Validaciones de formularios
- ✅ Manejo de errores

## Estructura del Proyecto

```
lib/
├── main.dart                 # Punto de entrada
├── router.dart              # Configuración de rutas
├── models/                  # Modelos de datos
│   ├── usuario.dart
│   └── cita_medica.dart
├── services/                # Servicios
│   └── supabase_service.dart
└── screens/                  # Pantallas
    ├── registro.dart
    ├── login.dart
    ├── bienvenida.dart
    └── agendar_cita.dart
```
