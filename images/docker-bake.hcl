group "default" {
    targets = [ "argocd-final"]
}

#################################################################################################################################################################
# Common Variables 
#################################################################################################################################################################
variable "CBO_VERSION" {
    default = "notset"
}

variable "VERSION" {
    default = "notset"
}

variable "BUILD_DATE" {
    default = "notset"
}

variable "COMMIT" {
    default = "notset"
}

variable "RSTATE" {
    default = "notset"
}

variable "PWD" {
    default = "notset"
}

variable "ARGO_CD_IMAGE_NAME_INTERNAL" {
    default = "notset"
}

variable "ARGO_CD_IMAGE_NAME" {
    default = "notset"
}

variable "ARGO_CD_IMAGE_USER_ID" {
    default = "notset"
}

variable "ARGO_CD_IMAGE_PRODUCT_NUMBER" {
    default = "notset"
}

variable "ARGO_CD_IMAGE_PRODUCT_TITLE" {
    default = "notset"
}

variable "ARGO_CD_VERSION" {
    default = "notset"
}

variable "GIT_COMMIT" {
    default = "notset"
}

variable "GIT_TAG" {
    default = "notset"
}

variable "GIT_TREE_STATE" {
    default = "notset"
}

variable "NODE_VERSION" {
    default = "notset"
}

variable "NPM_VERSION" {
    default = "notset"
}

variable "YARN_VERSION" {
    default = "notset"
}

#################################################################################################################################################################
# Argo CD final image
#################################################################################################################################################################


target "argocd-final" {
    context = "${PWD}/.bob/3pps/argo-cd"
    dockerfile = "${PWD}/images/argo-cd/Dockerfile"
    target = "argo-cd-final-image"
    tags = ["${ARGO_CD_IMAGE_NAME_INTERNAL}", "${ARGO_CD_IMAGE_NAME}"]    
    args = {
        GIT_COMMIT = GIT_COMMIT
        CBO_VERSION = CBO_VERSION
        GIT_TAG = GIT_TAG
        GIT_TREE_STATE = GIT_TREE_STATE
        BUILD_DATE = BUILD_DATE
        COMMIT = COMMIT
        APP_VERSION = VERSION
        RSTATE = RSTATE
        ARGOCD_USER_ID = ARGO_CD_IMAGE_USER_ID
        CBO_NODE_VERSION = NODE_VERSION
        CBO_NPM_VERSION = NPM_VERSION
        CBO_YARN_VERSION = YARN_VERSION
        IMAGE_PRODUCT_NUMBER=ARGO_CD_IMAGE_PRODUCT_NUMBER
        IMAGE_PRODUCT_TITLE=ARGO_CD_IMAGE_PRODUCT_TITLE   
        ARGO_CD_VERSION=ARGO_CD_VERSION
    }
}


