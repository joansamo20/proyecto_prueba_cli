/** Prueba mínima de Apps Script con contrato PE3/012. Sin datos clínicos. */
function doGet() {
  const resultado = prepararInterfaz_();
  switch (resultado.EstadoEjecucion012) {
    case 0:
      return resultado.Dato.vista;
    case 1:
      return HtmlService.createHtmlOutput('<h2>Estado indeterminado</h2><p>No se pudo preparar la interfaz.</p>');
    case 2:
      return HtmlService.createHtmlOutput('<h2>Error al cargar</h2><p>Revisa el informe de ejecución.</p>');
    default:
      return HtmlService.createHtmlOutput('<h2>Estado no reconocido</h2>');
  }
}

function prepararInterfaz_() {
  try {
    const vista = HtmlService.createHtmlOutputFromFile('Index')
      .setTitle('Agenda PE3 | Prueba Apps Script');
    return { EstadoEjecucion012: 0, Dato: { EstadoFuncional: 'InterfazPreparada', vista: vista } };
  } catch (error) {
    return { EstadoEjecucion012: 2, Dato: { EstadoFuncional: 'ErrorInterfaz', Diagnostico: String(error) } };
  }
}

function probarServidor() {
  const resultado = construirDiagnostico_();
  switch (resultado.EstadoEjecucion012) {
    case 0:
      return { EstadoEjecucion012: 0, Dato: resultado.Dato };
    case 1:
      return { EstadoEjecucion012: 1, Dato: { EstadoFuncional: 'RespuestaIncierta', Diagnostico: resultado.Dato } };
    case 2:
      return { EstadoEjecucion012: 2, Dato: { EstadoFuncional: 'PruebaFallida', Diagnostico: resultado.Dato } };
    default:
      return { EstadoEjecucion012: 2, Dato: { EstadoFuncional: 'EstadoInvalido' } };
  }
}

function construirDiagnostico_() {
  try {
    const ahora = new Date();
    if (Number.isNaN(ahora.getTime())) {
      return { EstadoEjecucion012: 1, Dato: { EstadoFuncional: 'HoraNoDisponible' } };
    }
    return {
      EstadoEjecucion012: 0,
      Dato: {
        EstadoFuncional: 'ServidorConectado',
        Fuente: 'Google Apps Script',
        FechaServidorISO: ahora.toISOString(),
        DuracionConsultaMin: 45,
        PagosReales: false,
        ReservasReales: false
      }
    };
  } catch (error) {
    return { EstadoEjecucion012: 2, Dato: { EstadoFuncional: 'Excepcion', Diagnostico: String(error) } };
  }
}
