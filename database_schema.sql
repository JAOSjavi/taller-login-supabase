-- ============================================
-- ESQUEMA DE BASE DE DATOS - SISTEMA DE SALUD
-- ============================================

-- 1. Crear tabla de documentos médicos (user_doc)
CREATE TABLE IF NOT EXISTS user_doc (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    nombre_archivo TEXT NOT NULL,
    pdf_url TEXT NOT NULL,
    tipo_documento TEXT DEFAULT 'historia_clinica', -- historia_clinica, examen, receta, etc.
    descripcion TEXT,
    fecha_subida TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Agregar columna user_doc_id a citas_medicas (opcional, para relacionar cita con documento específico)
-- Si ya existe pdf_url, podemos mantenerla por compatibilidad o migrar los datos
ALTER TABLE citas_medicas 
ADD COLUMN IF NOT EXISTS user_doc_id UUID REFERENCES user_doc(id) ON DELETE SET NULL;

-- 3. Crear índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_user_doc_usuario_id ON user_doc(usuario_id);
CREATE INDEX IF NOT EXISTS idx_user_doc_fecha_subida ON user_doc(fecha_subida DESC);
CREATE INDEX IF NOT EXISTS idx_citas_medicas_user_doc_id ON citas_medicas(user_doc_id);

-- 4. Habilitar RLS (Row Level Security) en user_doc
ALTER TABLE user_doc ENABLE ROW LEVEL SECURITY;

-- 5. Políticas RLS para user_doc

-- Permitir que todos vean los documentos (para que los médicos puedan acceder)
CREATE POLICY "Todos pueden ver documentos" ON user_doc
    FOR SELECT USING (true);

-- Permitir que todos inserten documentos
CREATE POLICY "Todos pueden insertar documentos" ON user_doc
    FOR INSERT WITH CHECK (true);

-- Permitir que todos actualicen documentos
CREATE POLICY "Todos pueden actualizar documentos" ON user_doc
    FOR UPDATE USING (true);

-- 6. Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 7. Trigger para actualizar updated_at en user_doc
CREATE TRIGGER update_user_doc_updated_at 
    BEFORE UPDATE ON user_doc
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 8. Función para migrar datos existentes (opcional)
-- Si ya tienes citas con pdf_url, puedes migrarlas a user_doc
CREATE OR REPLACE FUNCTION migrar_pdf_urls_a_user_doc()
RETURNS void AS $$
DECLARE
    cita_record RECORD;
    nuevo_doc_id UUID;
BEGIN
    -- Iterar sobre todas las citas que tienen pdf_url pero no user_doc_id
    FOR cita_record IN 
        SELECT id, usuario_id, pdf_url, created_at
        FROM citas_medicas
        WHERE pdf_url IS NOT NULL 
        AND pdf_url != ''
        AND user_doc_id IS NULL
    LOOP
        -- Crear un documento en user_doc
        INSERT INTO user_doc (
            usuario_id,
            nombre_archivo,
            pdf_url,
            tipo_documento,
            fecha_subida,
            created_at
        ) VALUES (
            cita_record.usuario_id,
            'historia_clinica_' || cita_record.id::text || '.pdf',
            cita_record.pdf_url,
            'historia_clinica',
            cita_record.created_at,
            cita_record.created_at
        ) RETURNING id INTO nuevo_doc_id;
        
        -- Actualizar la cita con el nuevo user_doc_id
        UPDATE citas_medicas
        SET user_doc_id = nuevo_doc_id
        WHERE id = cita_record.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 9. Comentarios en las tablas y columnas
COMMENT ON TABLE user_doc IS 'Almacena los documentos médicos de los usuarios (historias clínicas, exámenes, etc.)';
COMMENT ON COLUMN user_doc.usuario_id IS 'ID del usuario propietario del documento';
COMMENT ON COLUMN user_doc.nombre_archivo IS 'Nombre original del archivo';
COMMENT ON COLUMN user_doc.pdf_url IS 'URL del archivo PDF en el storage de Supabase';
COMMENT ON COLUMN user_doc.tipo_documento IS 'Tipo de documento: historia_clinica, examen, receta, etc.';
COMMENT ON COLUMN citas_medicas.user_doc_id IS 'ID del documento médico asociado a esta cita';

-- ============================================
-- INSTRUCCIONES DE USO:
-- ============================================
-- 1. Ejecuta este script completo en el SQL Editor de Supabase
-- 2. Si ya tienes citas con pdf_url, ejecuta después:
--    SELECT migrar_pdf_urls_a_user_doc();
-- 3. Verifica que las políticas RLS sean adecuadas para tu caso de uso
-- 4. Ajusta las políticas según tus necesidades de seguridad

