"
I build the GraphQL schema exposing Moose models generically (models, entities, meta-classes, properties and relations).

	MGSchema build.		""a fresh GQLSchema""
	MGSchema default.	""cached GQLSchema""
	MGSchema reset.		""forget the cached schema""

Resolvers expect an MGRegistry as user context; when the context is something else (e.g. nil) a fresh MGRegistry is used (see #registryFrom:).
List fields accept a 'take' argument: nil or negative means #defaultTake, and it is capped at #maxTake.
"
Class {
	#name : 'MGSchema',
	#superclass : 'Object',
	#classVars : [
		'Default'
	],
	#category : 'Moose-GraphQL-Schema',
	#package : 'Moose-GraphQL',
	#tag : 'Schema'
}

{ #category : 'helpers' }
MGSchema class >> arg: aName in: anArgumentDictionary [
	"Answer the argument named aName, or nil when absent"

	^ MGSafe
		  do: [
				  anArgumentDictionary ifNotNil: [ :args |
					  args at: aName ifAbsent: [ nil ] ] ]
		  default: nil
]

{ #category : 'building' }
MGSchema class >> build [
	"Answer a new GQLSchema exposing the installed Moose models"

	| builder |
	builder := GQLSchemaBuilder new.
	self
		defineQueryOn: builder;
		defineModelOn: builder;
		defineEntityOn: builder;
		definePropertyOn: builder;
		defineRelationOn: builder;
		defineMetaClassOn: builder.
	builder query: 'Query'.
	^ builder build
]

{ #category : 'accessing' }
MGSchema class >> default [
	"Cached schema, built on first use"
	^ Default ifNil: [ Default := self build ]
]

{ #category : 'accessing' }
MGSchema class >> defaultTake [
	"Number of elements answered by list fields when no 'take' argument is given."

	^ 100
]

{ #category : 'building' }
MGSchema class >> defineEntityOn: aBuilder [

	aBuilder
		object: 'Entity'
		description: 'A Moose entity (any element of a model).'
		fields: [ :o |
				o
					field: 'id'
					type: 'ID!'
					description: 'Opaque id (<modelId>:<mooseID>).'
					resolve: [ :e :args :ctx |
					(self registryFrom: ctx) idOfEntity: e ].
				o
					field: 'name'
					type: 'String'
					description: 'Entity name, or its mooseName when it has no name.'
					resolve: [ :e :args :ctx |
					(self registryFrom: ctx) nameOfEntity: e ].
				o
					field: 'mooseName'
					type: 'String'
					description: 'Qualified Moose name.'
					resolve: [ :e :args :ctx |
					(self registryFrom: ctx) mooseNameOf: e ].
				o
					field: 'type'
					type: 'String'
					description: 'Name of the entity meta-class.'
					resolve: [ :e :args :ctx |
					(self registryFrom: ctx) typeOfEntity: e ].
				o
					field: 'model'
					type: 'Model'
					description: 'Model containing the entity.'
					resolve: [ :e :args :ctx |
					(self registryFrom: ctx) knownModelOf: e ].
				o
					field: 'metaClass'
					type: 'MetaClass'
					description: 'Meta-class (FM3 description) of the entity.'
					resolve: [ :e :args :ctx |
					(self registryFrom: ctx) metaClassOf: e ].
				o
					field: 'properties'
					type: '[Property!]!'
					description: 'Primitive properties, sorted by name.'
					resolve: [ :e :args :ctx |
					(self registryFrom: ctx) propertiesOf: e ].
				o
					field: 'relations'
					type: '[Relation!]!'
					description: 'Relations to other entities, sorted by name.'
					resolve: [ :e :args :ctx |
					(self registryFrom: ctx) relationsOf: e ].
				o
					field: 'related'
					type: '[Entity!]!'
					description:
					'Distinct entities reachable through the stored relations.'
					args: { ('take' -> 'Int') }
					resolve: [ :e :args :ctx |
							(self registryFrom: ctx)
								relatedOf: e
								take: (self arg: 'take' in: args) ] ]
]

{ #category : 'building' }
MGSchema class >> defineMetaClassOn: aBuilder [

	aBuilder
		object: 'MetaClass'
		description:
		'A meta-class (FM3 class) of a model, i.e. an entity type.'
		fields: [ :o |
				o
					field: 'id'
					type: 'ID!'
					description: 'Opaque id (<modelId>:<fullName>).'
					resolve: [ :m :args :ctx | m id ].
				o
					field: 'name'
					type: 'String'
					description: 'Short name (e.g. Class).'
					resolve: [ :m :args :ctx | m name ].
				o
					field: 'fullName'
					type: 'String'
					description: 'Qualified name (e.g. FamixJava-Entities.Class).'
					resolve: [ :m :args :ctx | m fullName ].
				o
					field: 'superclass'
					type: 'MetaClass'
					description: 'Meta-class this one inherits from.'
					resolve: [ :m :args :ctx | m superclass ].
				o
					field: 'count'
					type: 'Int'
					description: 'Number of instances in the model.'
					resolve: [ :m :args :ctx | m count ].
				o
					field: 'instances'
					type: '[Entity!]!'
					description:
					'Entities of the model having exactly this meta-class.'
					args: { ('take' -> 'Int') }
					resolve: [ :m :args :ctx |
					m instances: (self arg: 'take' in: args) ] ]
]

{ #category : 'building' }
MGSchema class >> defineModelOn: aBuilder [

	aBuilder
		object: 'Model'
		description: 'An installed Moose model.'
		fields: [ :o |
				o
					field: 'id'
					type: 'ID!'
					description: 'Opaque id (index in the installed models).'
					resolve: [ :model :args :ctx |
					(self registryFrom: ctx) idOfModel: model ].
				o
					field: 'name'
					type: 'String'
					description: 'Model name.'
					resolve: [ :model :args :ctx |
					(self registryFrom: ctx) modelNameOf: model ].
				o
					field: 'size'
					type: 'Int'
					description: 'Number of entities.'
					resolve: [ :model :args :ctx |
					(self registryFrom: ctx) modelSizeOf: model ].
				o
					field: 'metamodelName'
					type: 'String'
					description:
					'Model class, identifying its metamodel (e.g. FamixJavaModel).'
					resolve: [ :model :args :ctx |
					(self registryFrom: ctx) metamodelNameOf: model ].
				o
					field: 'entityTypes'
					type: '[MetaClass!]!'
					description:
					'Meta-classes having instances in this model, sorted by name.'
					args: { ('take' -> 'Int') }
					resolve: [ :model :args :ctx |
							(self registryFrom: ctx)
								entityTypesOf: model
								take: (self arg: 'take' in: args) ].
				o
					field: 'entities'
					type: '[Entity!]!'
					description:
					'Entities of this model, optionally of one meta-class (name or fullName).'
					args: {
							('take' -> 'Int').
							('type' -> 'String') }
					resolve: [ :model :args :ctx |
							(self registryFrom: ctx)
								entitiesOf: model
								type: (self arg: 'type' in: args)
								take: (self arg: 'take' in: args) ] ]
]

{ #category : 'building' }
MGSchema class >> definePropertyOn: aBuilder [

	aBuilder
		object: 'Property'
		description: 'A primitive (non-entity) property of an entity.'
		fields: [ :o |
				o
					field: 'id'
					type: 'ID!'
					description: 'Opaque id (<entityId>/<name>).'
					resolve: [ :p :args :ctx | p id ].
				o
					field: 'name'
					type: 'String'
					description: 'Property name.'
					resolve: [ :p :args :ctx | p name ].
				o
					field: 'type'
					type: 'String'
					description: 'Declared type name (e.g. String, Number, Boolean).'
					resolve: [ :p :args :ctx | p type ].
				o
					field: 'value'
					type: 'String'
					description:
					'Printed value; <error: ...> when it cannot be computed.'
					resolve: [ :p :args :ctx | p value ].
				o
					field: 'isDerived'
					type: 'Boolean'
					description: 'True when the value is computed.'
					resolve: [ :p :args :ctx | p isDerived ].
				o
					field: 'owner'
					type: 'Entity'
					description: 'Entity owning the property.'
					resolve: [ :p :args :ctx | p owner ] ]
]

{ #category : 'building' }
MGSchema class >> defineQueryOn: aBuilder [

	aBuilder
		object: 'Query'
		description: 'Entry points to explore the installed Moose models.'
		fields: [ :o |
				o
					field: 'models'
					type: '[Model!]!'
					description: 'Installed Moose models.'
					args: { ('take' -> 'Int') }
					resolve: [ :src :args :ctx |
						(self registryFrom: ctx) modelsTake: (self arg: 'take' in: args) ].
				o
					field: 'model'
					type: 'Model'
					description: 'A model by id (index) or by name.'
					args: { ('id' -> 'ID!') }
					resolve: [ :src :args :ctx |
						(self registryFrom: ctx) modelAt: (self arg: 'id' in: args) ].
				o
					field: 'entities'
					type: '[Entity!]!'
					description:
					'Entities, optionally restricted to one model and/or one meta-class name.'
					args: {
							('take' -> 'Int').
							('modelId' -> 'ID').
							('type' -> 'String') }
					resolve: [ :src :args :ctx |
							(self registryFrom: ctx)
								entitiesTake: (self arg: 'take' in: args)
								modelId: (self arg: 'modelId' in: args)
								type: (self arg: 'type' in: args) ].
				o
					field: 'entity'
					type: 'Entity'
					description:
					'An entity by id (<modelId>:<mooseID> or bare mooseID).'
					args: { ('id' -> 'ID!') }
					resolve: [ :src :args :ctx |
						(self registryFrom: ctx) entityAt: (self arg: 'id' in: args) ].
				o
					field: 'metaClass'
					type: 'MetaClass'
					description: 'A meta-class by id (<modelId>:<fullName>).'
					args: { ('id' -> 'ID!') }
					resolve: [ :src :args :ctx |
						(self registryFrom: ctx) metaClassAt: (self arg: 'id' in: args) ].
				o
					field: 'relation'
					type: 'Relation'
					description: 'A relation by id (<entityId>/<name>).'
					args: { ('id' -> 'ID!') }
					resolve: [ :src :args :ctx |
						(self registryFrom: ctx) relationAt: (self arg: 'id' in: args) ].
				o
					field: 'property'
					type: 'Property'
					description: 'A primitive property by id (<entityId>/<name>).'
					args: { ('id' -> 'ID!') }
					resolve: [ :src :args :ctx |
						(self registryFrom: ctx) propertyAt: (self arg: 'id' in: args) ] ]
]

{ #category : 'building' }
MGSchema class >> defineRelationOn: aBuilder [

	aBuilder
		object: 'Relation'
		description: 'A relation from an entity to other entities.'
		fields: [ :o |
				o
					field: 'id'
					type: 'ID!'
					description: 'Opaque id (<entityId>/<name>).'
					resolve: [ :r :args :ctx | r id ].
				o
					field: 'name'
					type: 'String'
					description: 'Relation name.'
					resolve: [ :r :args :ctx | r name ].
				o
					field: 'type'
					type: 'String'
					description: 'Declared type name of the targets.'
					resolve: [ :r :args :ctx | r type ].
				o
					field: 'isMultivalued'
					type: 'Boolean'
					description: 'True when the relation holds a collection.'
					resolve: [ :r :args :ctx | r isMultivalued ].
				o
					field: 'isContainer'
					type: 'Boolean'
					description: 'True when the target contains the owner.'
					resolve: [ :r :args :ctx | r isContainer ].
				o
					field: 'isDerived'
					type: 'Boolean'
					description:
					'True when the relation is derived (opposite side or computed).'
					resolve: [ :r :args :ctx | r isDerived ].
				o
					field: 'size'
					type: 'Int'
					description: 'Number of target entities.'
					resolve: [ :r :args :ctx | r size ].
				o
					field: 'target'
					type: 'Entity'
					description: 'First target entity, if any.'
					resolve: [ :r :args :ctx | r target ].
				o
					field: 'targets'
					type: '[Entity!]!'
					description: 'Target entities.'
					args: { ('take' -> 'Int') }
					resolve: [ :r :args :ctx |
					r targets: (self arg: 'take' in: args) ].
				o
					field: 'owner'
					type: 'Entity'
					description: 'Entity owning the relation.'
					resolve: [ :r :args :ctx | r owner ] ]
]

{ #category : 'accessing' }
MGSchema class >> maxTake [
	"Upper bound of the 'take' argument of list fields."

	^ 1000
]

{ #category : 'helpers' }
MGSchema class >> registryFrom: aContext [
	"Answer aContext when it is an MGRegistry, a fresh MGRegistry otherwise"

	^ (aContext isKindOf: MGRegistry)
		  ifTrue: [ aContext ]
		  ifFalse: [ MGRegistry new ]
]

{ #category : 'accessing' }
MGSchema class >> reset [
	"Forget the cached schema (e.g. after changing the schema definition)"
	Default := nil
]
