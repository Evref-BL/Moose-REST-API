"
I represent the source code of a model entity
"
Class {
	#name : #MRModelSourceCode,
	#superclass : #Object,
	#instVars : [
		'fileName',
		'sourceCode'
	],
	#category : #'Moose-REST-API-Model'
}

{ #category : #accessing }
MRModelSourceCode class >> neoJsonMapping: mapper [

	mapper for: self do: [ :mapping | mapping mapAllInstVars ]
]

{ #category : #accessing }
MRModelSourceCode >> fileName [

	"The filename where the source code is stored"

	<OPEN_API_variable: #fileName type: #string>
	^ fileName
]

{ #category : #accessing }
MRModelSourceCode >> fileName: anObject [

	fileName := anObject
]

{ #category : #accessing }
MRModelSourceCode >> sourceCode [

	"The actual source code of the model entity"

	<OPEN_API_variable: #sourceCode type: #string>
	^ sourceCode
]

{ #category : #accessing }
MRModelSourceCode >> sourceCode: anObject [

	sourceCode := anObject
]
