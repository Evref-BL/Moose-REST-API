"
I am the abstract superclass of the GraphQL composite output types that declare fields: object types and interface types.

I hold an ordered dictionary of field definitions and the interfaces I implement. Interfaces are first declared by name (#addInterfaceNamed:) and resolved against a schema (#resolveInterfacesIn:) once all the types are registered.
"
Class {
	#name : 'GQLCompositeType',
	#superclass : 'GQLType',
	#instVars : [
		'fields',
		'interfaceNames',
		'interfaces'
	],
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'instance creation' }
GQLCompositeType class >> name: aString [

	^ self new
		  name: aString;
		  yourself
]

{ #category : 'accessing' }
GQLCompositeType >> addField: aFieldDefinition [

	(fields includesKey: aFieldDefinition name) ifTrue: [
			^ self error:
				  'Field "' , aFieldDefinition name
				  , '" is already defined in type "' , name asString , '"' ].
	^ fields at: aFieldDefinition name put: aFieldDefinition
]

{ #category : 'accessing' }
GQLCompositeType >> addInterfaceNamed: aStringOrInterfaceType [
	"Declare that the receiver implements the interface named aStringOrInterfaceType (a name or a GQLInterfaceType).
	The interface is resolved against the schema by #resolveInterfacesIn:. Answer the interface name"

	| interfaceName |
	interfaceName := aStringOrInterfaceType isString
		                 ifTrue: [ aStringOrInterfaceType asString ]
		                 ifFalse: [ aStringOrInterfaceType name asString ].
	(interfaceNames includes: interfaceName) ifTrue: [
			^ self error:
				  'Interface "' , interfaceName
				  , '" is already implemented by type "' , name asString , '"' ].
	^ interfaceNames add: interfaceName
]

{ #category : 'accessing' }
GQLCompositeType >> allInterfaces [
	"Answer all the interfaces implemented by the receiver, directly or transitively, without duplicates and in discovery order.
	Safe against cycles (and does not include the receiver itself)"

	| result visited pending |
	result := OrderedCollection new.
	visited := IdentitySet with: self.
	pending := OrderedCollection withAll: self interfaces.
	[ pending isEmpty ] whileFalse: [
			| each |
			each := pending removeFirst.
			(visited includes: each) ifFalse: [
					visited add: each.
					result add: each.
					pending addAll: each interfaces ] ].
	^ result asArray
]

{ #category : 'accessing' }
GQLCompositeType >> fieldNamed: aString [

	^ fields at: aString asString ifAbsent: [ nil ]
]

{ #category : 'accessing' }
GQLCompositeType >> fields [
	"OrderedDictionary name -> GQLFieldDefinition"

	^ fields
]

{ #category : 'testing' }
GQLCompositeType >> implements: anInterfaceTypeOrName [
	"Answer whether the receiver implements, directly or transitively, the interface given as a GQLInterfaceType or a name"

	| interfaceName |
	anInterfaceTypeOrName ifNil: [ ^ false ].
	interfaceName := anInterfaceTypeOrName isString
		                 ifTrue: [ anInterfaceTypeOrName asString ]
		                 ifFalse: [ anInterfaceTypeOrName name asString ].
	^ self allInterfaces anySatisfy: [ :each | each name = interfaceName ]
]

{ #category : 'initialization' }
GQLCompositeType >> initialize [

	super initialize.
	fields := OrderedDictionary new.
	interfaceNames := OrderedCollection new.
	interfaces := #(  )
]

{ #category : 'accessing' }
GQLCompositeType >> interfaceNames [
	"Names of the interfaces the receiver declares to implement, in declaration order"

	^ interfaceNames asArray
]

{ #category : 'accessing' }
GQLCompositeType >> interfaces [
	"Answer the GQLInterfaceTypes directly implemented by the receiver (introspection __Type.interfaces).
	Empty until the interface names are resolved by #resolveInterfacesIn:"

	^ interfaces
]

{ #category : 'testing' }
GQLCompositeType >> isComposite [

	^ true
]

{ #category : 'resolving' }
GQLCompositeType >> resolveFieldTypesIn: aSchema [

	fields do: [ :each | each resolveTypeIn: aSchema ]
]

{ #category : 'resolving' }
GQLCompositeType >> resolveInterfacesIn: aSchema [
	"Resolve the declared interface names against aSchema. Signal an Error for unknown names or for types that are not interfaces"

	interfaces := (interfaceNames collect: [ :each |
			               | type |
			               type := (aSchema typeNamed: each) ifNil: [
					                       ^ self error:
						                         'Unknown interface "' , each
						                         , '" implemented by type "'
						                         , name asString , '"' ].
			               type isInterface ifFalse: [
					               ^ self error:
						                 'Type "' , each , '" implemented by type "'
						                 , name asString , '" is not an interface' ].
			               type ]) asArray
]
