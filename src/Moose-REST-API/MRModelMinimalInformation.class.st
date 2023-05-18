"
I represent minimal information about a Model.
"
Class {
	#name : #MRModelMinimalInformation,
	#superclass : #Object,
	#instVars : [
		'id',
		'name'
	],
	#category : #'Moose-REST-API-Model'
}

{ #category : #accessing }
MRModelMinimalInformation class >> neoJsonMapping: mapper [

	mapper for: self do: [ :mapping | mapping mapAllInstVars ]
]

{ #category : #accessing }
MRModelMinimalInformation >> id [

	"I represent the id of the model inside the Moose system"

	<OPEN_API_variable: #id type: #integer>
	^ id
]

{ #category : #accessing }
MRModelMinimalInformation >> id: anObject [

	id := anObject
]

{ #category : #accessing }
MRModelMinimalInformation >> name [

	"I am the name of the model"

	<OPEN_API_variable: #name type: #string>
	^ name
]

{ #category : #accessing }
MRModelMinimalInformation >> name: anObject [

	name := anObject
]
