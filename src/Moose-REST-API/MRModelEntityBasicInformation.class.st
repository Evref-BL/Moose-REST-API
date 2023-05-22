"
I represent basic information about an entity of the model.
"
Class {
	#name : #MRModelEntityBasicInformation,
	#superclass : #Object,
	#instVars : [
		'name',
		'fmid',
		'type'
	],
	#category : #'Moose-REST-API-Model'
}

{ #category : #accessing }
MRModelEntityBasicInformation class >> from: aMooseEntity [

	^ self new
		  name: aMooseEntity name;
		  fmid: aMooseEntity mooseID;
		  type:
			  (aMooseEntity mooseModel metaDescriptionOf: aMooseEntity)
				  fullName;
		  yourself
]

{ #category : #accessing }
MRModelEntityBasicInformation class >> neoJsonMapping: mapper [

	mapper for: self do: [ :mapping | mapping mapAllInstVars ]
]

{ #category : #accessing }
MRModelEntityBasicInformation >> fmid [

	"I represent the id that you **must** use when asking for  *entityFMID*"

	<OPEN_API_variable: #fmid type: #integer>
	^ fmid
]

{ #category : #accessing }
MRModelEntityBasicInformation >> fmid: anObject [

	fmid := anObject
]

{ #category : #accessing }
MRModelEntityBasicInformation >> name [

	"I am the name of the entity in the model"

	<OPEN_API_variable: #name type: #string>
	^ name
]

{ #category : #accessing }
MRModelEntityBasicInformation >> name: anObject [

	name := anObject
]

{ #category : #accessing }
MRModelEntityBasicInformation >> type [

	"The complete name of type of the entity"

	<OPEN_API_variable: #type type: #string>
	^ type
]

{ #category : #accessing }
MRModelEntityBasicInformation >> type: anObject [

	type := anObject
]
