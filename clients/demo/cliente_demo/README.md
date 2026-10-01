# Cliente Demo

App de personalizacion del cliente ficticio `demo`. Sirve de plantilla para clientes reales.

Regla: solo lo que es propio de este cliente. Lo que se repite en dos clientes sube a `agentic_base`.

Ejemplo incluido:
- Campo `posicion_ncm` en Articulo (fixture de Custom Field).
- Validacion del formato NCM (`0000.00.00` o `0000.00.00.000X`) al guardar el articulo.
- Tests unitarios de la validacion y de integracion del campo instalado.
