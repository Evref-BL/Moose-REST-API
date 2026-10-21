# Moose-REST-API

Lets other tools query Moose models over HTTP. It includes a generic GraphQL server that works with any metamodel, plus the original REST API.

## Features

- **Moose-GraphQL**: one GraphQL schema that works with any Moose model (models, entities, meta-classes, properties and relations). Start it with one line: `MGServer start`.
- **Model mode**: serve one model, with its metamodel's entity types (`Class`, `Method`, ...) as GraphQL concepts: `MGServer startOnModel: aModel`. See [Model mode](#model-mode).
- **GraphQL-Core**: a GraphQL engine that does not depend on Moose. It has a parser, a schema DSL, an executor, introspection, and a Zinc HTTP server with CORS.
- **Errors stay local**: a field that fails returns `null` and adds an entry to `errors`. The rest of the response is still returned.
- **Works with fluid**, the GraphQL graph explorer, through introspection.
- **Legacy REST API** (`Moose-REST-API`, based on Teapot/Tealight).

## Installation

You need a Moose image. The baseline does not declare Moose as a dependency.

### Full installation

Loads the `default` group: every package, including the legacy REST API.

```st
Metacello new
  githubUser: 'evref-bl' project: 'Moose-REST-API' commitish: 'master' path: 'src';
  baseline: 'MooseRestAPI';
  load
```

### GraphQL server only

```st
Metacello new
  baseline: 'MooseRestAPI';
  repository: 'github://evref-bl/Moose-REST-API:master/src';
  load: #('Moose-GraphQL').
```

To also load the tests, use `load: #('Moose-GraphQL' 'Tests')`.

### Packages and groups

| Package | Content |
|---|---|
| `Moose-REST-API`, `Moose-REST-API-Generator` | Legacy REST API (Teapot/Tealight) |
| `GraphQL-Core` | GraphQL engine that does not need Moose (depends on NeoJSON) |
| `GraphQL-Core-Tests` | Tests for the engine |
| `Moose-GraphQL` | GraphQL schema for Moose models, plus `MGServer` |
| `Moose-GraphQL-Tests` | Tests for the Moose GraphQL server |

| Group | Content |
|---|---|
| `default` | All six packages |
| `GraphQL` | `GraphQL-Core` only (it does **not** include the Moose server) |
| `GraphQL-Tests` | GraphQL test package |
| `Tests` | `GraphQL-Core-Tests` and `Moose-GraphQL-Tests` |

There is no `Moose-GraphQL` group. To load the server, load the `Moose-GraphQL` package by name, as shown above.

## Quick start

### 1. Load a model

```st
model := '/path/to/model.json' asFileReference
	readStreamDo: [ :s | FamixJavaModel new importFromJSONStream: s ].
model name: 'MyModel'; install.
```

- The import names the model after the file's base name. To use another name, rename the model before `install`.
- For MSE files, use `importFromMSEStream:` instead:
  `'/path/model.mse' asFileReference readStreamDo: [ :s | FamixJavaModel new importFromMSEStream: s ]`.
- Use the model class for your metamodel (for Java, `FamixJavaModel`).
- The server shows every model installed in `MooseModel root`, so models loaded from the Moose UI appear too.
- To remove a model, use `model remove`.

### 2. Start the server

```st
MGServer start.                 "port 4000"
MGServer startOn: 8080.         "custom port"
MGServer current url.           "'http://localhost:4000/graphql'"
MGServer isRunning.
MGServer stop.
```

- The server listens on the loopback interface only. Both `localhost` and `127.0.0.1` work.
- `startOn:` stops any server that is already running.
- The server builds a new model registry for each request, so models you install appear right away.
- To serve one model with its own entity types as concepts, see [Model mode](#model-mode).

### 3. Query it

```bash
curl -X POST http://localhost:4000/graphql \
  -H 'content-type: application/json' \
  -d '{"query":"{ models { id name size } }"}'
```

```json
{"data":{"models":[{"id":"1","name":"MyModel","size":2}]}}
```

### HTTP protocol

- Endpoint: `/graphql` (`/` also works).
- `GET` with `?query=...&operationName=...&variables=<json>`.
- `POST` with `application/json` (`{"query": ..., "operationName": ..., "variables": ...}`), or `application/graphql` with the raw query as the body.
- `OPTIONS` answers the CORS preflight. Every response includes `Access-Control-Allow-Origin: *`.
- GraphQL errors come back as HTTP 200 with a JSON body that contains `data`, `errors`, or both.

## Using with fluid

fluid is a GraphQL graph explorer. It reads the schema through introspection.

1. Start the server with `MGServer start`.
2. Run fluid's frontend locally. It uses the Vite dev server at `http://localhost:5173`.
3. fluid's local `.env` sets `VITE_DEFAULT_GRAPHQL_URL="http://localhost:4000/graphql"` by default, so it connects to the server on its own. You can also type the URL in the Connect screen.

> The public HTTPS deployment of fluid cannot reach `http://localhost`, because browsers block mixed content and private-network requests. Use a copy of fluid running locally.

## Schema

In generic mode (`MGServer start`), the schema is generic and works with any metamodel. For a schema built from the entity types of one model, see [Model mode](#model-mode).

```graphql
type Query {
  models(take: Int): [Model!]!
  model(id: ID!): Model                 # index or model name
  entities(take: Int, modelId: ID, type: String): [Entity!]!
  entity(id: ID!): Entity               # <modelId>:<mooseID> or bare mooseID
  metaClass(id: ID!): MetaClass         # <modelId>:<FM3 fullName>
  relation(id: ID!): Relation           # <entityId>/<name>
  property(id: ID!): Property           # <entityId>/<name>
}

type Model {
  id: ID!
  name: String
  size: Int
  metamodelName: String
  entityTypes(take: Int): [MetaClass!]!
  entities(take: Int, type: String): [Entity!]!
}

type Entity {
  id: ID!
  name: String
  mooseName: String
  type: String
  model: Model
  metaClass: MetaClass
  properties: [Property!]!
  relations: [Relation!]!
  related(take: Int): [Entity!]!
}

type MetaClass {
  id: ID!
  name: String
  fullName: String
  superclass: MetaClass
  count: Int
  instances(take: Int): [Entity!]!
}

type Property {
  id: ID!
  name: String
  type: String
  value: String
  isDerived: Boolean
  owner: Entity
}

type Relation {
  id: ID!
  name: String
  type: String
  isMultivalued: Boolean
  isContainer: Boolean
  isDerived: Boolean
  size: Int
  target: Entity
  targets(take: Int): [Entity!]!
  owner: Entity
}
```

Notes:

- `take` defaults to 100 and is capped at 1000. A missing or negative value means 100.
- The `type` filter accepts a meta-class name (`Method`) or a full name.
- Property `value` is the printed value as a string, cut to 1000 characters. If the value cannot be computed, it is `<error: ...>`.
- Relation `type` is the type declared in FM3. It can be a trait, for example `TMethod`.
- `related` returns the distinct entities reachable through stored relations, including the opposite sides.
- Ids are opaque strings. An unknown or malformed id returns `null`, never an error. mooseIDs change from one image to another.

## Example queries

The results below come from a tiny test model. Your mooseIDs will differ.

### List a model's entity types and entities

```graphql
query ListEntities($model: ID!, $take: Int) {
  model(id: $model) {
    name metamodelName
    entityTypes { id name fullName count }
    entities(take: $take) { id name type }
  }
}
```

Variables:

```json
{"model": "MyModel", "take": 10}
```

Result (trimmed):

```json
{"data":{"model":{"name":"MyModel","metamodelName":"FamixJavaModel",
 "entityTypes":[{"id":"1:FamixJava-Entities.Class","name":"Class","fullName":"FamixJava-Entities.Class","count":1}, ...],
 "entities":[{"id":"1:53668","name":"Foo","type":"Class"},{"id":"1:53669","name":"bar","type":"Method"}]}}}
```

### Inspect an entity

```graphql
query Entity($id: ID!) {
  entity(id: $id) {
    id name type
    properties { name type value }
    relations { id name size targets(take: 5) { id name type } }
  }
}
```

Result (trimmed):

```json
{"data":{"entity":{"id":"1:53668","name":"Foo","type":"Class",
 "properties":[{"name":"isStub","type":"Boolean","value":"false"},{"name":"name","type":"String","value":"Foo"}, ...],
 "relations":[{"id":"1:53668/methods","name":"methods","size":1,"targets":[{"id":"1:53669","name":"bar","type":"Method"}]}, ...]}}}
```

### Filter entities by type across all models

```graphql
{ entities(type: "Method", take: 5) { id name model { name } } }
```

## Model mode

The generic mode (`MGServer start` / `MGServer startOn: aPort`) is unchanged. It exposes every installed model through the meta-level concepts `Model`, `Entity`, `MetaClass`, `Property` and `Relation`.

Model mode exposes **one** model. Its concepts are the entity types of the model's metamodel. For example, on a FamixSmalltalk model the concepts are `Class`, `Method`, `Access`, and so on.

### Start a model server

```st
model := MooseModel root detect: [ :m | m name = 'MyModel' ].
MGServer startOnModel: model.          "port 4000"
MGServer startOn: 8080 model: model.   "custom port"
MGServer currentModel.                 "the served model, nil in generic mode"
MGServer restart.                      "same port and model, schema rebuilt"
MGServer stop.                         "also clears currentModel"
```

- The schema is a snapshot of the model's types at start. If the model changes, call `MGServer restart` to rebuild it.
- An empty model raises `MGEmptyModelError` (`Model <name> has no entity to expose`). A server that is already running is left untouched.

### Concepts

- A root concept is created for each concrete metamodel class that has at least one instance in the model.
- Each root concept gets two root query fields:
  - a plural lowerFirst list, `[T!]!` with `take: Int`, e.g. `classes`, `methods`, `attributes`;
  - a singular by-id field, `T` with `id: ID!`, e.g. `class(id:)`. An id of another concept returns `null`.
- A concept's list also includes the instances of its conforming subclasses.

### Fields

- Every type has `id: ID!`, `name: String` and `type: String` (the concrete meta-class name).
- Each primitive FM3 property adds one scalar field (`[T]` when multivalued). Scalars are `String`, `Boolean`, and a custom `Number` scalar that keeps integers. Other values are printed as `String`.
- Derived properties are included. A value that cannot be computed resolves to `null`.
- A property named `id` is exposed as `id_`. Properties named `name` or `type` are shadowed by the identity fields.

### Relations

- When exactly one concept conforms to the declared FM3 type, the relation is typed with that concept, e.g. `Class.methods: [Method!]!` and `Method.parentType: Class`. Multivalued relations take `take: Int`.
- When no concept with instances conforms to the target type, the relation is dropped (for example comments or tags when the model has none).
- When two or more concepts conform, the relation is typed with a hidden helper type named after the trait (e.g. `TWithComments`). It is navigable, but it has no root query, so it does not appear on the Concepts page.

### Naming

Types use the short FM3 name (`Class`, `Method`). On a collision, or when the short name is reserved by GraphQL, the sanitized full name is used instead (e.g. `FamixTest1Entities_Class`).

### Example

```graphql
{ classes(take: 5) { id name type methods(take: 3) { id name parentType { name } } } }
```

### Main classes

| Class | Role |
|---|---|
| `MGModelSchemaBuilder` | `buildFor: aMooseModel` builds the model-mode schema |
| `MGConcept` | One GraphQL type of the model: a root concept or a hidden helper type |
| `MGRegistry` | Per-request context; `forModel:` creates it for one model |
| `MGEmptyModelError` | Signaled when the model has no entity to expose |

## Resilience

- If one field fails, that field becomes `null` and an entry is added to `errors`. The rest of the response is kept.
- A Moose property that cannot be read never breaks its entity.
- An unknown id returns `null`.
- Lists are capped (`take` is at most 1000).
- The server always answers with JSON and CORS headers.
- The engine is lenient: it reports unknown fields and still runs the rest of the query.

## Using GraphQL-Core on its own

`GraphQL-Core` does not depend on Moose. You can use it to serve your own schema. Load it with the `GraphQL` group.

```st
| builder schema |
builder := GQLSchemaBuilder new.
builder object: 'Query' fields: [ :o |
	o field: 'hello' type: 'String' resolve: [ :src :args :ctx | 'world' ].
	o field: 'greet' type: 'String!' args: { 'name' -> 'String!' }
		resolve: [ :src :args :ctx | 'Hello ' , (args at: 'name') ] ].
builder query: 'Query'.
schema := builder build.
schema execute: '{ hello }'.
(GQLHttpServer on: 4001 schema: schema) start.
```

## Legacy REST API

The original REST API packages (`Moose-REST-API`, `Moose-REST-API-Generator`, based on Teapot/Tealight) are still included in the full installation.

## Tests

Load the `Tests` group. It contains the test packages `GraphQL-Core-Tests` and `Moose-GraphQL-Tests`. Model mode is tested by `MGModelSchemaTest` and `MGModelServerTest` in `Moose-GraphQL-Tests`.
