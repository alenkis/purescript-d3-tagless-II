exports.emptyD3Data_ = null

const debug = false;

// d3SelectAll_ :: Selector -> D3Selection
exports.d3SelectAllInDOM_ = selector => { // NB not USING selection but want it cause called from inside State Monad
  if (debug) {console.log(`\td3SelectAllInDOM: ${selector}`);}
  return d3.selectAll(selector);
} 
// d3SelectAll_ :: Selector -> D3Selection
exports.d3SelectionSelectAll_ = selector => selection => {
  if (debug) {console.log(`\td3SelectionSelectAll: ${selection}.selectAll(${selector})`);}
  return selection.selectAll(selector);
} 
// d3Enter_ :: D3Selection -> D3Selection
exports.d3EnterAndAppend_ = element => selection => {
  if (debug) {console.log(`\td3EnterAndAppend: ${selection}.enter().append(${element})`);}
  return selection.enter().append(element);
}
// d3Exit_ :: D3Selection -> D3Selection
exports.d3Exit_ = selection => {
  if (debug) {console.log(`\td3Exit: ${selection}.exit()`);}
  return selection.exit();
}
// d3AddTransition :: D3Selection -> D3Selection
exports.d3AddTransition = selection => transition => {
  var handle; 
  if (transition.name == "") {
    if (debug) {console.log(`\td3addTransition: ${selection}.transition(${transition})`);}
    handle = selection.transition();
    // if transition is unnamed we configure it...
    if (transition.duration != 0) {
      if (debug) {console.log(`transition.duration(${transition.duration})`);}
      handle.duration(transition.duration);
    }
    if (transition.delay != 0) {
      if (debug) {console.log(`transition.delay(${transition.delay})`);}
      handle.delay(transition.delay);
    }
  } else {
    // TODO check if named transition then we presume delay and duration etc all set up already??
    console.log(`\td3addNamedTransition: ${selection}.transition(${transition})`);
    handle = selection.transition(transition.name);
  }
  return handle; 
}

// d3RemoveSelection_ :: D3Selection -> D3Selection
exports.d3RemoveSelection_ = selection => {
  if (debug) {console.log(`\td3Remove: ${selection}.remove()`);}
  if (debug) {console.log(selection);}
  return selection.remove();
}
// d3Append_ :: String -> D3Selection -> D3Selection
exports.d3Append_ = element => selection => {
  if (debug) {console.log(`\td3Append: ${selection}.append(${element})`);}
  return selection.append(element);
}
// d3Data_ :: D3Data -> D3Selection -> D3Selection
exports.d3Data_ = data => projection => selection => {
  if (debug) {console.log(`\td3Data: ${selection}.data(${data})`);}
  return selection.data(projection(data), d => d );
}
// d3Data_ :: D3Data -> KeyFunction -> D3Selection -> D3Selection
exports.d3DataKeyFn_ = data => projection => keyFunction => selection => {
  if (debug) {console.log(`\td3Data: ${selection}.data(${data}, ${keyFunction})`);}
  return selection.data(projection(data), keyFunction);
}
// d3SetAttr_      :: String -> D3Attr -> D3Selection -> Unit 
exports.d3SetAttr_ = name => value => selection => {
  if (debug) {
    console.log(`\t${selection}.attr(${name}, ${value})`);
  }
  return selection.attr(name, value);
}

// d3SetAttr_      :: String -> D3Attr -> D3Selection -> Unit 
exports.d3SetText_ = value => selection => {
  if (debug) {(`\t${selection}.text(${value})`);}
  return selection.text(value);
}


