Class {
	#name : #MRModelMetaClassModel,
	#superclass : #Object,
	#instVars : [
		'name',
		'implementationName'
	],
	#category : #'Moose-REST-API-Model'
}

{ #category : #accessing }
MRModelMetaClassModel class >> neoJsonMapping: mapper [

	mapper for: self do: [ :mapping | mapping mapAllInstVars ]
]

{ #category : #accessing }
MRModelMetaClassModel >> implementationName [

	"I am the concrete name of the concept. You might use me in other API endpoints"

	<OPEN_API_variable: #name type: #string>
	^ implementationName
]

{ #category : #accessing }
MRModelMetaClassModel >> implementationName: anObject [

	implementationName := anObject
]

{ #category : #accessing }
MRModelMetaClassModel >> name [

	"I am the name in the meta-model of the concept"

	<OPEN_API_variable: #name type: #string>
	^ name
]

{ #category : #accessing }
MRModelMetaClassModel >> name: anObject [

	name := anObject
]
