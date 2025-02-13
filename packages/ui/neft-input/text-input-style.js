const { Renderer } = require('@neft/core')

const { setPropertyValue } = Renderer.itemUtils

class TextInput extends Renderer.Native {
  focus() {
    this.call('focus')
  }
}

TextInput.__name__ = 'TextInput'

TextInput.Initialize = (item) => {
  item.on('textChange', function (value) {
    setPropertyValue(this, 'text', String(value || ''))
  })
}

TextInput.defineProperty({
  type: 'text',
  name: 'text',
})

TextInput.defineProperty({
  type: 'color',
  name: 'textColor',
})

TextInput.defineProperty({
  type: 'text',
  name: 'placeholder',
})

TextInput.defineProperty({
  type: 'color',
  name: 'placeholderColor',
})

// text, numeric, email, tel
TextInput.defineProperty({
  type: 'text',
  name: 'keyboardType',
  implementationValue: val => String(val || '').toLowerCase(),
})

TextInput.defineProperty({
  type: 'boolean',
  name: 'multiline',
})

// done, go, next, search, send, null
TextInput.defineProperty({
  type: 'text',
  name: 'returnKeyType',
  implementationValue: val => String(val || '').toLowerCase(),
})

TextInput.defineProperty({
  type: 'boolean',
  name: 'secureTextEntry',
})

module.exports = TextInput
