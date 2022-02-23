FROM golang:1.17-alpine AS builder

RUN apk add git make curl

RUN git clone -b v1.4.0 https://github.com/dinumathai/pushgateway.git 

WORKDIR pushgateway

RUN make common-build

FROM alpine:3.15

COPY --from=builder /go/pushgateway/pushgateway /bin/pushgateway

USER 65534

ENTRYPOINT [ "/bin/pushgateway" ]