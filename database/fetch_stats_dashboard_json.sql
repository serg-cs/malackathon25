-- Stats dashboard aggregated JSON payload for Oracle Autonomous Database 26ai
WITH
  atenciones_por_fecha AS (
    SELECT TRUNC(COALESCE(a.fecha_ingreso, a.fecha_alta)) AS fecha,
           COUNT(*) AS total_atenciones
    FROM atencion_sanitaria a
    WHERE a.fecha_ingreso IS NOT NULL OR a.fecha_alta IS NOT NULL
    GROUP BY TRUNC(COALESCE(a.fecha_ingreso, a.fecha_alta))
  ),
  estancias_base AS (
    SELECT NVL(s.nombre, 'Sin especificar') AS sexo_nombre,
           ROUND(a.fecha_alta - a.fecha_ingreso, 2) AS dias_estancia
    FROM atencion_sanitaria a
    LEFT JOIN paciente p ON p.id = a.paciente_id
    LEFT JOIN sexo s ON s.id = p.sexo_id
    WHERE a.fecha_ingreso IS NOT NULL
      AND a.fecha_alta IS NOT NULL
      AND a.fecha_alta >= a.fecha_ingreso
  ),
  estancias_resumen AS (
    SELECT sexo_nombre,
           dias_estancia,
           COUNT(*) AS total_estancias
    FROM estancias_base
    GROUP BY sexo_nombre, dias_estancia
  ),
  tipo_alta_vs_severidad AS (
    SELECT NVL(ta.nombre, 'Sin especificar') AS tipo_alta_nombre,
           NVL(a.nivel_severidad, -1) AS nivel_severidad,
           COUNT(*) AS total
    FROM atencion_sanitaria a
    LEFT JOIN tipo_alta ta ON ta.id = a.tipo_alta_id
    GROUP BY NVL(ta.nombre, 'Sin especificar'), NVL(a.nivel_severidad, -1)
  ),
  coste_por_regimen AS (
    SELECT NVL(rf.nombre, 'Sin especificar') AS regimen_financiacion,
           ROUND(SUM(a.coste), 2) AS coste_total
    FROM atencion_sanitaria a
    LEFT JOIN regimen_financiacion rf ON rf.id = a.regimen_financiacion_id
    GROUP BY NVL(rf.nombre, 'Sin especificar')
  ),
  diagnostico_por_sexo AS (
    SELECT d.id AS diagnostico_id,
           d.codigo AS diagnostico_codigo,
           NVL(d.nombre, 'Sin nombre') AS diagnostico_nombre,
           NVL(s.nombre, 'Sin especificar') AS sexo_nombre,
           COUNT(*) AS total
    FROM atencion_sanitaria__diagnostico asd
    JOIN diagnostico d ON d.id = asd.diagnostico_id
    JOIN atencion_sanitaria a ON a.id = asd.atencion_sanitaria_id
    LEFT JOIN paciente p ON p.id = a.paciente_id
    LEFT JOIN sexo s ON s.id = p.sexo_id
    GROUP BY d.id, d.codigo, NVL(d.nombre, 'Sin nombre'), NVL(s.nombre, 'Sin especificar')
  ),
  diagnostico_top AS (
    SELECT diagnostico_id,
           diagnostico_codigo,
           diagnostico_nombre,
           SUM(total) AS total_global,
           JSON_ARRAYAGG(
             JSON_OBJECT('sexo' VALUE sexo_nombre, 'total' VALUE total RETURNING CLOB)
             ORDER BY sexo_nombre
             RETURNING CLOB
           ) AS totales_por_sexo,
           ROW_NUMBER() OVER (ORDER BY SUM(total) DESC, diagnostico_nombre) AS rnk
    FROM diagnostico_por_sexo
    GROUP BY diagnostico_id, diagnostico_codigo, diagnostico_nombre
  ),
  procedimiento_por_sexo AS (
    SELECT pr.id AS procedimiento_id,
           pr.codigo AS procedimiento_codigo,
           NVL(pr.nombre, 'Sin nombre') AS procedimiento_nombre,
           NVL(s.nombre, 'Sin especificar') AS sexo_nombre,
           COUNT(*) AS total
    FROM atencion_sanitaria__procedimiento asp
    JOIN procedimiento pr ON pr.id = asp.procedimiento_id
    JOIN atencion_sanitaria a ON a.id = asp.atencion_sanitaria_id
    LEFT JOIN paciente p ON p.id = a.paciente_id
    LEFT JOIN sexo s ON s.id = p.sexo_id
    GROUP BY pr.id, pr.codigo, NVL(pr.nombre, 'Sin nombre'), NVL(s.nombre, 'Sin especificar')
  ),
  procedimiento_top AS (
    SELECT procedimiento_id,
           procedimiento_codigo,
           procedimiento_nombre,
           SUM(total) AS total_global,
           JSON_ARRAYAGG(
             JSON_OBJECT('sexo' VALUE sexo_nombre, 'total' VALUE total RETURNING CLOB)
             ORDER BY sexo_nombre
             RETURNING CLOB
           ) AS totales_por_sexo,
           ROW_NUMBER() OVER (ORDER BY SUM(total) DESC, procedimiento_nombre) AS rnk
    FROM procedimiento_por_sexo
    GROUP BY procedimiento_id, procedimiento_codigo, procedimiento_nombre
  )
SELECT JSON_OBJECT(
         'atencionesPorFecha' VALUE (
           SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                      'fecha' VALUE TO_CHAR(fecha, 'YYYY-MM-DD'),
                      'total' VALUE total_atenciones
                    RETURNING CLOB
                    )
                    ORDER BY fecha
                    RETURNING CLOB
                  )
           FROM atenciones_por_fecha
         ) FORMAT JSON,
         'estanciasPorSexo' VALUE (
           SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                      'sexo' VALUE sexo_nombre,
                      'estanciaMedia' VALUE ROUND(AVG(dias_estancia), 2),
                      'estanciaMinima' VALUE ROUND(MIN(dias_estancia), 2),
                      'estanciaMaxima' VALUE ROUND(MAX(dias_estancia), 2),
                      'distribucion' VALUE (
                        SELECT JSON_ARRAYAGG(
                                 JSON_OBJECT(
                                   'dias' VALUE dias_estancia,
                                   'total' VALUE total_estancias
                                 RETURNING CLOB
                                 )
                                 ORDER BY dias_estancia
                                 RETURNING CLOB
                               )
                        FROM estancias_resumen sr2
                        WHERE sr2.sexo_nombre = sb1.sexo_nombre
                      ) FORMAT JSON
                    RETURNING CLOB
                    )
                    ORDER BY sexo_nombre
                    RETURNING CLOB
                  )
           FROM estancias_base sb1
           GROUP BY sexo_nombre
         ) FORMAT JSON,
         'tipoAltaPorSeveridad' VALUE (
           SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                      'tipoAlta' VALUE tipo_alta_nombre,
                      'nivelSeveridad' VALUE nivel_severidad,
                      'total' VALUE total
                    RETURNING CLOB
                    )
                    ORDER BY tipo_alta_nombre, nivel_severidad
                    RETURNING CLOB
                  )
           FROM tipo_alta_vs_severidad
         ) FORMAT JSON,
         'costePorRegimen' VALUE (
           SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                      'regimenFinanciacion' VALUE regimen_financiacion,
                      'costeTotal' VALUE coste_total
                    RETURNING CLOB
                    )
                    ORDER BY coste_total DESC
                    RETURNING CLOB
                  )
           FROM coste_por_regimen
         ) FORMAT JSON,
         'diagnosticosComunes' VALUE (
           SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                      'diagnosticoId' VALUE diagnostico_id,
                      'codigo' VALUE diagnostico_codigo,
                      'nombre' VALUE diagnostico_nombre,
                      'total' VALUE total_global,
                      'porSexo' VALUE totales_por_sexo FORMAT JSON
                    RETURNING CLOB
                    )
                    ORDER BY total_global DESC, diagnostico_nombre
                    RETURNING CLOB
                  )
           FROM diagnostico_top
           WHERE rnk <= 10
         ) FORMAT JSON,
         'procedimientosComunes' VALUE (
           SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                      'procedimientoId' VALUE procedimiento_id,
                      'codigo' VALUE procedimiento_codigo,
                      'nombre' VALUE procedimiento_nombre,
                      'total' VALUE total_global,
                      'porSexo' VALUE totales_por_sexo FORMAT JSON
                    RETURNING CLOB
                    )
                    ORDER BY total_global DESC, procedimiento_nombre
                    RETURNING CLOB
                  )
           FROM procedimiento_top
           WHERE rnk <= 10
         ) FORMAT JSON
       RETURNING CLOB
       ) AS charts_payload
FROM dual;
