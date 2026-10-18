'use strict';
class DomainError extends Error {
  constructor(code, status) {
    super(code);
    this.code = code;
    this.status = status;
  }
}
module.exports = { DomainError };
