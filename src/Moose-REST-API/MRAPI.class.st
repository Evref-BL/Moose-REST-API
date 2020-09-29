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
