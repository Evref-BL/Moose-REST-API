"
Resilience tests: the GraphQL layer must answer data (never let an exception escape) when property computations raise, when entities have a nil or raising meta-description, and when a model itself is broken.
"
Class {
	#name : 'MGResilienceTest',
	#superclass : 'MGTestCase',
	#category : 'Moose-GraphQL-Tests',
	#package : 'Moose-GraphQL-Tests'
}

{ #category : 'tests' }
MGResilienceTest >> testBrokenModelInRegistry [
	"A model whose #entities and #size raise (never installed; handed to the registry via useModels:) does not break the registry nor queries"

	| broken reg response models |
	broken := MGBrokenModel new
		          name: 'MGTestBroken';
		          yourself.
	reg := MGRegistry new.
	reg useModels: {
			broken.
			model }.
	self
		shouldnt: [
				self assert: (reg idOfModel: broken) equals: '1'.
				self assert: (reg modelSizeOf: broken) isNil.
				self assert: (reg entitiesOf: broken type: nil) isEmpty.
				self assert: (reg entityTypesOf: broken) isEmpty.
				self assert: (reg entityAt: '1:1') isNil.
				self assert: (reg metaClassAt: '1:Method') isNil.
				"bare id lookup scans the broken model first, then finds the entity in the healthy one"
				self
					assert: (reg entityAt: class1 mooseID printString)
					identicalTo: class1 ]
		raise: Error.
	self
		shouldnt: [
				response := MGSchema default
					            execute:
					            '{ models { id name size metamodelName entityTypes { name } entities { id } } entities { id name } }'
					            operationName: nil
					            variables: nil
					            context: reg ]
		raise: Error.
	self
		deny: (response includesKey: 'errors')
		description: [
		(response at: 'errors' ifAbsent: [ nil ]) printString ].
	models := (response at: 'data') at: 'models'.
	self assert: models size equals: 2.
	self assert: (models first at: 'name') equals: 'MGTestBroken'.
	self assert: (models first at: 'size') isNil.
	self assert: (models first at: 'entities') isEmpty.
	self assert: (models second at: 'entities') size equals: 6.
	self assert: ((response at: 'data') at: 'entities') size equals: 6
]

{ #category : 'tests' }
MGResilienceTest >> testContainmentOnBrokenEntities [
	"Containment and supertype protocol on entities with nil or raising metadescription never raise: answers nil / empty / 0 / true"

	| broken |
	broken := {
		(MGBrokenEntity new raising: false; yourself).
		(MGBrokenEntity new raising: true; yourself) }.
	model addAll: broken.
	broken do: [ :b |
		self
			shouldnt: [
				self assert: (self registry containersOf: b) isEmpty.
				self assert: (self registry containerOf: b) isNil.
				self assert: (self registry childrenOf: b take: nil) isEmpty.
				self assert: (self registry childrenCountOf: b) equals: 0.
				self assert: (self registry ancestorsOf: b take: nil) isEmpty.
				self assert: (self registry isRootEntity: b).
				self assert: (self registry supertypeNamesOf: b) isEmpty ]
			raise: Error ]
]

{ #category : 'tests' }
MGResilienceTest >> testContainmentOnBrokenModel [
	"Root entities of a model whose #entities raises are empty; the healthy model is still served"

	| broken reg |
	broken := MGBrokenModel new
		name: 'MGTestBroken';
		yourself.
	reg := MGRegistry new.
	reg useModels: { broken. model }.
	self
		shouldnt: [
			self assert: (reg rootEntitiesOf: broken take: nil) isEmpty.
			self assert: (reg rootEntitiesTake: nil modelId: (reg idOfModel: broken)) isEmpty.
			self
				assert: (reg rootEntitiesTake: nil modelId: (reg idOfModel: model)) asArray
				equals: { class1. class2 }.
			self assert: ((reg rootEntitiesTake: nil modelId: nil) includes: class1) ]
		raise: Error
]

{ #category : 'tests' }
MGResilienceTest >> testContainmentQueryOnBrokenEntities [
	"GraphQL containment fields on broken entities answer null / [] / 0 without GraphQL errors"

	| broken response entity |
	broken := {
		(MGBrokenEntity new raising: false; yourself).
		(MGBrokenEntity new raising: true; yourself) }.
	model addAll: broken.
	broken do: [ :b |
		self
			shouldnt: [
				response := self
					query: 'query($id: ID!) { entity(id: $id) { id container { id } containers { id } children { id } childrenCount ancestors { id } types } }'
					variables: (Dictionary with: 'id' -> (self idOf: b)) ]
			raise: Error.
		self
			deny: (response includesKey: 'errors')
			description: [ (response at: 'errors' ifAbsent: [ nil ]) printString ].
		entity := (response at: 'data') at: 'entity'.
		self assert: (entity at: 'id') equals: (self idOf: b).
		self assert: (entity at: 'container') isNil.
		self assert: (entity at: 'containers') isEmpty.
		self assert: (entity at: 'children') isEmpty.
		self assert: (entity at: 'childrenCount') equals: 0.
		self assert: (entity at: 'ancestors') isEmpty.
		self assert: (entity at: 'types') isEmpty ].
	self
		shouldnt: [
			response := self query: '{ rootEntities(modelId: "' , self modelId , '") { id } }' ]
		raise: Error.
	self deny: (response includesKey: 'errors')
]

{ #category : 'tests' }
MGResilienceTest >> testEntitiesWithBrokenMetadescription [
	"A non-Famix entity whose metadescription is nil, and one whose metadescription/name/mooseName raise, are added to the model:
	every query still answers data and no exception escapes"

	| nilDescribed raising response entities brokenIds |
	nilDescribed := MGBrokenEntity new
		                raising: false;
		                yourself.
	raising := MGBrokenEntity new
		           raising: true;
		           yourself.
	model
		add: nilDescribed;
		add: raising.
	self
		shouldnt: [
				response := self
					            query:
					            'query($m: ID!) { model(id: $m) { size entityTypes { name count } entities { id name mooseName type metaClass { id } model { id } properties { name value } relations { name size targets { id } } related { id } } } }'
					            variables: (Dictionary with: 'm' -> self modelId) ]
		raise: Error.
	self
		deny: (response includesKey: 'errors')
		description: [
		(response at: 'errors' ifAbsent: [ nil ]) printString ].
	entities := ((response at: 'data') at: 'model') at: 'entities'.
	self assert: entities size equals: 8.
	brokenIds := {
		             (self idOf: nilDescribed).
		             (self idOf: raising) }.
	brokenIds do: [ :id |
			| entity |
			entity := entities detect: [ :e | (e at: 'id') = id ].
			self assert: (entity at: 'type') equals: 'MGBrokenEntity'.
			self assert: (entity at: 'metaClass') isNil.
			self assert: (entity at: 'properties') isEmpty.
			self assert: (entity at: 'relations') isEmpty.
			self assert: (entity at: 'related') isEmpty ].
	self
		assert:
		((entities detect: [ :e | (e at: 'id') = brokenIds first ]) at:
			 'name')
		equals: 'brokenEntity'.
	self assert:
		((entities detect: [ :e | (e at: 'id') = brokenIds second ]) at:
			 'name') isNil.
	"meta-classes ignore entities without description"
	self
		assert:
			((((response at: 'data') at: 'model') at: 'entityTypes') collect: [
				 :t | t at: 'name' ]) asArray
		equals: #( 'Attribute' 'Class' 'Method' ).
	"direct lookups by id"
	brokenIds do: [ :id |
			self
				shouldnt: [
						response := self
							            query:
							            'query($id: ID!, $r: ID!) { entity(id: $id) { id name type properties { value } } relation(id: $r) { id } }'
							            variables: (Dictionary new
									             at: 'id' put: id;
									             at: 'r' put: id , '/x';
									             yourself) ]
				raise: Error.
			self deny: (response includesKey: 'errors').
			self
				assert: (((response at: 'data') at: 'entity') at: 'id')
				equals: id.
			self assert: ((response at: 'data') at: 'relation') isNil ]
]

{ #category : 'tests' }
MGResilienceTest >> testRaisingPropertyIsReportedAsValue [
	"numberOfAbstractMethods raises internally on FamixTest1Class (FamixTest1Method does not understand isAbstract):
	the property value becomes '<error: ...>' and the query reports no GraphQL error"

	| property value data viaProperty viaEntity |
	property := self registry propertyAt:
		            (self idOf: class1) , '/numberOfAbstractMethods'.
	self assert: property notNil.
	self shouldnt: [ value := property value ] raise: Error.
	self assert: (value beginsWith: '<error').
	data := self
		        dataOf:
		        'query($pid: ID!, $eid: ID!) { property(id: $pid) { name value } entity(id: $eid) { properties { name value } } }'
		        variables: (Dictionary new
				         at: 'pid'
				         put: (self idOf: class1) , '/numberOfAbstractMethods';
				         at: 'eid' put: (self idOf: class1);
				         yourself).
	viaProperty := (data at: 'property') at: 'value'.
	self assert: (viaProperty beginsWith: '<error').
	viaEntity := ((data at: 'entity') at: 'properties') detect: [ :p |
		             (p at: 'name') = 'numberOfAbstractMethods' ].
	self assert: ((viaEntity at: 'value') beginsWith: '<error').
	"other properties are unaffected"
	self
		assert: ((((data at: 'entity') at: 'properties') detect: [ :p |
				  (p at: 'name') = 'name' ]) at: 'value')
		equals: 'Class1'
]
