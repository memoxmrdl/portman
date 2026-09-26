# Portman

Módulo de gestión de portafolio para una app de inversiones personales. Un
`Portfolio` tiene una colección de `Stock`, una asignación objetivo (por
ejemplo 40% META y 60% APPL) y un método `rebalance` que indica qué acciones
vender y cuáles comprar para volver a esa asignación.

La solución se puede revisar de dos formas: **leyendo y ejecutando los tests**
o **usando la aplicación en el navegador**.

## Requisitos

- Ruby 4.0.6 (ver `.ruby-version`)
- `bundle install`
- **No se necesita base de datos.** Aunque el proyecto se generó con
  PostgreSQL, el dominio está hecho con objetos Ruby planos (POROs), no con
  Active Record. Postgres no tiene que estar corriendo ni para los tests ni
  para la aplicación.

## Opción 1: revisar la solución en los tests

    bin/rails test

Los tests describen el comportamiento esperado y son la mejor forma de
entender la solución:

| Archivo | Qué demuestra |
| --- | --- |
| `test/models/stock_test.rb` | El ticker se guarda tal cual (APPL nunca se convierte en AAPL). `current_price` guarda y devuelve el último precio disponible, y rechaza precios vacíos, cero o negativos. |
| `test/models/portfolio_test.rb` | Registro de tenencias (cantidad por acción) y de la asignación objetivo. Los pesos deben sumar 100 (o 1.0); si no, se rechaza la asignación. |
| `test/models/portfolio_rebalance_test.rb` | El rebalanceo: caso canónico, plan vacío cuando ya está balanceado, venta total de lo que no está en el objetivo, compra desde cero, cantidades fraccionarias, y falla completa si falta algún precio. |
| `test/integration/portfolios_rebalance_test.rb` | El flujo HTTP: formulario en `GET /` y plan recomendado en `POST /rebalance`. |

Caso canónico: con 50 META a 100 y 50 APPL a 100, y objetivo 40% META / 60%
APPL, el plan recomienda **vender 10 META y comprar 10 APPL**.

Para correr un solo archivo:

    bin/rails test test/models/portfolio_rebalance_test.rb

## Opción 2: revisar la aplicación corriendo

    bin/dev

Abrir http://localhost:3000. El formulario viene precargado con 50 META y
50 APPL al mismo precio y objetivo 40/60, así que al enviarlo recomienda
vender 10 META y comprar 10 APPL. Se pueden cambiar tickers, cantidades, precios y pesos
objetivo, y al enviar se muestra el plan de compra/venta. Si los pesos no
suman 100, se muestra el error "Invalid allocation" y no se genera plan.

## Decisiones de diseño

- **Solo recomienda:** `rebalance` devuelve un `RebalancePlan` y nunca modifica
  las tenencias del portafolio.
- **Deriva por valor:** `valor = cantidad × precio`, `objetivo = peso × total`
  y `cantidad a operar = diferencia de valor / precio`. Se permiten acciones
  fraccionarias y los cálculos usan `Rational` para evitar errores de
  redondeo.
- **Falla cerrada:** si alguna acción no tiene precio válido, falla todo el
  rebalanceo; no se omite ni se inventa un precio.

## Por qué no se necesita Postgres

- `config/environments/test.rb`: `config.active_record.maintain_test_schema = false`.
- `config/environments/development.rb`: `config.active_record.migration_error = false`.
- `test/test_helper.rb`: `self.use_transactional_tests = false`, sin
  `fixtures :all` y sin `parallelize` (los workers paralelos se quedaban
  esperando un `db/schema.rb` que no existe).

La gema `pg` y `config/database.yml` se dejaron para una futura capa de
persistencia.
