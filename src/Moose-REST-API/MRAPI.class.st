Class {
	#name : #MRAPI,
	#superclass : #Object,
	#category : #'Moose-REST-API'
}

{ #category : #'class initialization' }
MRAPI class >> initialize [
	TLRESTApiURLPathBuilder useAPIPrefix: '/moose'.
	TLRESTAPIBuilder buildAPI
]

{ #category : #'class initialization' }
MRAPI class >> inspect [
	<script>
	TLWebserver teapot inspect
]

{ #category : #'class initialization' }
MRAPI class >> reset [
	<script>
	TLWebserver teapot removeAllDynamicRoutes
]

{ #category : #accessing }
MRAPI class >> retrieveEntity: aRequest [
	"I need a model and the entity id"

	| model entityID |
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	entityID := (aRequest at: #entityFMID) asInteger.
	^ model detect: [ :el | el mooseID == entityID ]
]

{ #category : #api }
MRAPI class >> retrieveModel: aRequest [
	"I need a model"

	^ MooseModel root at: (aRequest at: #modelID) asInteger
]
