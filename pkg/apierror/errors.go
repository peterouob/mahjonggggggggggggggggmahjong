package apierror

import "net/http"

// Code is a machine-readable error identifier returned in all error responses.
type Code string

const (
	CodeUnauthenticated        Code = "UNAUTHENTICATED"
	CodeForbidden              Code = "FORBIDDEN"
	CodeNotFound               Code = "NOT_FOUND"
	CodeValidationError        Code = "VALIDATION_ERROR"
	CodeUserAlreadyExists      Code = "USER_ALREADY_EXISTS"
	CodeInvalidCredentials     Code = "INVALID_CREDENTIALS"
	CodeBroadcastAlreadyActive Code = "BROADCAST_ALREADY_ACTIVE"
	CodeBroadcastAgeRestricted Code = "BROADCAST_AGE_RESTRICTED"
	CodeRoomFull               Code = "ROOM_FULL"
	CodeRoomNotJoinable        Code = "ROOM_NOT_JOINABLE"
	CodeAlreadyInRoom          Code = "ALREADY_IN_ROOM"
	CodeFriendLimitExceeded    Code = "FRIEND_LIMIT_EXCEEDED"
	CodeAlreadyFriend          Code = "ALREADY_FRIEND"
	CodeFriendRequestExists    Code = "FRIEND_REQUEST_EXISTS"
	CodeAlreadyBlocked         Code = "ALREADY_BLOCKED"
	CodeRateLimited            Code = "RATE_LIMITED"
	CodeInternalError          Code = "INTERNAL_ERROR"
)

// APIError is the standard error returned by all service and handler layers.
type APIError struct {
	Code    Code   `json:"code"`
	Message string `json:"message"`
	Status  int    `json:"-"`
}

func (e *APIError) Error() string {
	return e.Message
}

func New(status int, code Code, message string) *APIError {
	return &APIError{Status: status, Code: code, Message: message}
}

// Convenience constructors for common errors.

func Unauthenticated(msg string) *APIError {
	return New(http.StatusUnauthorized, CodeUnauthenticated, msg)
}

func Forbidden(msg string) *APIError {
	return New(http.StatusForbidden, CodeForbidden, msg)
}

func NotFound(msg string) *APIError {
	return New(http.StatusNotFound, CodeNotFound, msg)
}

func BadRequest(code Code, msg string) *APIError {
	return New(http.StatusBadRequest, code, msg)
}

func Conflict(code Code, msg string) *APIError {
	return New(http.StatusConflict, code, msg)
}

func TooManyRequests() *APIError {
	return New(http.StatusTooManyRequests, CodeRateLimited, "Too many requests, please slow down")
}

func Internal() *APIError {
	return New(http.StatusInternalServerError, CodeInternalError, "Internal server error")
}
